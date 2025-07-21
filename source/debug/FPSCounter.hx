package debug;

import flixel.FlxG;
import openfl.Lib;
import haxe.Timer;
import openfl.text.TextField;
import openfl.text.TextFormat;
import lime.system.System as LimeSystem;
import states.MainMenuState;
import debug.GameVersion;
import openfl.display.Sprite;
import openfl.display.Shape;
import flixel.FlxState;
import flixel.util.FlxColor;
import openfl.utils.Assets;
import backend.ClientPrefs;
import backend.Paths;
import flixel.math.FlxMath;

#if cpp
#if windows
@:cppFileCode('#include <windows.h>')
#elseif (ios || mac)
@:cppFileCode('#include <mach-o/arch.h>')
#else
@:headerInclude('sys/utsname.h')
#end
#end
class FPSCounter extends Sprite
{
	public var currentFPS(default, null):Int;
	public var memoryMegas(get, never):Float;
	public var memoryPeakMegas(default, null):Float = 0;

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var lastFramerateUpdateTime:Float;
	@:noCompletion private var updateTime:Int;
	@:noCompletion private var framesCount:Int;
	@:noCompletion private var prevTime:Int;

	public var objectCount(default, null):Int = 0;

	@:noCompletion private var lastObjectCountUpdate:Float = 0;
	@:noCompletion private var lastDelayUpdateTime:Float = 0;
	@:noCompletion private var currentDelay:Float = 0;

	public var os:String = '';

	// 文本字段
	private var fpsText:TextField;
	private var ramText:TextField;
	private var peakText:TextField;
	private var delayText:TextField;
	private var versionText:TextField;
	private var objectsText:TextField;

	// 背景和装饰元素
	private var background:Shape;
	private var statusIndicator:Shape;

	// 布局参数
	private var padding:Float = 8;
	private var indicatorSize:Float = 12;
	private var indicatorSpacing:Float = 4;
	private var cornerRadius:Float = 8;

	// 性能优化变量
	private var lastFpsUpdateTime:Float = 0;
	private var lastRamUpdateTime:Float = 0;
	private var lastObjectsUpdateTime:Float = 0;
	
	// 背景平滑过渡变量
	private var targetWidth:Float = 200; // 稍微增加宽度以适应更大的字体
	private var targetHeight:Float = 120;
	private var currentWidth:Float = 200;
	private var currentHeight:Float = 120;
	private var lerpSpeed:Float = 0.2;
	
	// 修复：添加缺失的变量声明
	@:noCompletion private var lastExGameVersion:Bool;
	@:noCompletion private var lastShowRunningOS:Bool;

	public var fontName:String = Paths.font("vcr.ttf");

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		// 创建半透明背景
		background = new Shape();
		drawBackground(0x222222, 0.85, currentWidth, currentHeight);
		addChild(background);

		// 创建状态指示器
		statusIndicator = new Shape();
		statusIndicator.graphics.beginFill(0x00FF00, 0.9);
		statusIndicator.graphics.drawRoundRect(0, 0, indicatorSize, indicatorSize, 4);
		statusIndicator.graphics.endFill();
		addChild(statusIndicator);

		// 创建文本字段 - 调整文本大小以提高可读性
		fpsText = createTextField(20, 0xFFFFFF, true); // 增大主FPS文本
		ramText = createTextField(16, 0x66AAFF);      // RAM增大
		peakText = createTextField(16, 0xFFA500);     // MEM Peak增大
		delayText = createTextField(16, 0xFFFF00);    // Delay增大
		versionText = createTextField(12, 0xCCCCCC);  // 版本信息保持原大小
		objectsText = createTextField(14, 0x00FF00);  // Objects增大

		addChild(fpsText);
		addChild(ramText);
		addChild(peakText);
		addChild(delayText);
		addChild(versionText);
		addChild(objectsText);

		#if !officialBuild
		if (LimeSystem.platformName == LimeSystem.platformVersion || LimeSystem.platformVersion == null)
			os = 'OS: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end;
		else
			os = 'OS: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end + ' - ${LimeSystem.platformVersion}';
		#end

		// 修复：初始化设置跟踪变量
		lastExGameVersion = ClientPrefs.data.exgameversion;
		lastShowRunningOS = ClientPrefs.data.showRunningOS;

		// 设置静态版本信息
		updateVersionText();

		positionFPS(x, y);

		currentFPS = 0;
		times = [];
		lastFramerateUpdateTime = Timer.stamp();
		prevTime = Lib.getTimer();
		updateTime = prevTime + 500;
		framesCount = 0;

		// 初始化更新时间
		lastFpsUpdateTime = Timer.stamp();
		lastRamUpdateTime = Timer.stamp();
		lastObjectsUpdateTime = Timer.stamp();
		
		// 初始化背景尺寸
		positionTextElements();
	}

	private function updateVersionText():Void
	{
		var versionTextContent = '';
		if (ClientPrefs.data.exgameversion)
		{
			versionTextContent = 'Psych v${MainMenuState.psychEngineVersion}';
			versionTextContent += '\nMR v${MainMenuState.mrExtendVersion}';
			versionTextContent += '\nCommit: ${GameVersion.getGitCommitCount()} (${GameVersion.getGitCommitHash()})';
		}

		if (ClientPrefs.data.showRunningOS)
			versionTextContent += '\n' + os;

		versionText.text = versionTextContent;
	}

	private function drawBackground(color:Int, alpha:Float, width:Float, height:Float):Void
	{
		background.graphics.clear();
		background.graphics.beginFill(color, alpha);
		background.graphics.drawRoundRect(0, 0, width, height, cornerRadius);
		background.graphics.endFill();

		// 添加边框
		background.graphics.lineStyle(1, 0xFFFFFF, 0.2);
		background.graphics.drawRoundRect(0, 0, width, height, cornerRadius);
	}

	private function createTextField(size:Int, color:Int, bold:Bool = false):TextField
	{
		var tf = new TextField();
		tf.selectable = false;
		tf.mouseEnabled = false;

		tf.defaultTextFormat = new TextFormat(fontName, size, color, bold);
		tf.autoSize = LEFT;
		return tf;
	}

	public dynamic function updateText():Void
	{
		var currentTime = Timer.stamp();
		var memory = memoryMegas;

		// 检查设置是否变化
		if (ClientPrefs.data.exgameversion != lastExGameVersion || ClientPrefs.data.showRunningOS != lastShowRunningOS)
		{
			lastExGameVersion = ClientPrefs.data.exgameversion;
			lastShowRunningOS = ClientPrefs.data.showRunningOS;
			updateVersionText();
		}

		// 更新内存峰值
		if (memory > memoryPeakMegas)
		{
			memoryPeakMegas = memory;
		}

		// 限制FPS更新频率（每秒最多20次）
		if (currentTime - lastFpsUpdateTime > 0.05)
		{
			// 更新 FPS 文本
			fpsText.text = 'FPS: $currentFPS';

			// 根据 FPS 设置颜色和指示器
			var fpsColor:Int;
			if (currentFPS < FlxG.stage.window.frameRate * 0.5)
			{
				fpsColor = 0xFFFF4444;
				setIndicatorState(false);
			}
			else if (currentFPS < FlxG.stage.window.frameRate * 0.75)
			{
				fpsColor = 0xFFFFFF66;
				setIndicatorState(true);
			}
			else
			{
				fpsColor = 0xFF66FF66;
				setIndicatorState(true);
			}
			fpsText.textColor = fpsColor;

			lastFpsUpdateTime = currentTime;
		}

		// 限制RAM更新频率（每秒最多4次）
		if (currentTime - lastRamUpdateTime > 0.25)
		{
			// 更新内存信息
			ramText.text = 'RAM: ${flixel.util.FlxStringUtil.formatBytes(memory)}';
			ramText.textColor = memory > 1024 * 1024 * 500 ? 0xFFFF6666 : 0xFF66AAFF;

			// 更新内存峰值
			peakText.text = 'MEM Peak: ${flixel.util.FlxStringUtil.formatBytes(memoryPeakMegas)}';
			peakText.textColor = 0xFFFFA500;

			lastRamUpdateTime = currentTime;
		}

		// 限制延迟更新频率（每秒最多10次）
		if (currentTime - lastDelayUpdateTime > 0.1)
		{
			// 计算并显示延迟
			if (currentFPS > 0)
			{
				currentDelay = Math.fround(1000.0 / currentFPS * 10) / 10;
			}
			else
			{
				currentDelay = 0;
			}
			delayText.text = 'Delay: ${currentDelay}ms';
			delayText.textColor = currentDelay > 16.7 ? 0xFFFF6666 : 0xFFFFFF66;

			lastDelayUpdateTime = currentTime;
		}

		// 限制对象计数更新频率（每秒最多2次）
		if (currentTime - lastObjectsUpdateTime > 0.5)
		{
			// 更新对象数量
			objectsText.text = 'Objects: $objectCount';
			objectsText.textColor = objectCount > 2000 ? 0xFFFF6666 : 0xFF66FF66;

			lastObjectsUpdateTime = currentTime;
		}

		// 更新背景尺寸
		positionTextElements();
	}

	private function setIndicatorState(active:Bool):Void
	{
		statusIndicator.alpha = active ? 0.9 : 0.4;
		if (!active)
		{
			statusIndicator.transform.colorTransform = new openfl.geom.ColorTransform(1.0, 0.5, 0.5);
		}
		else
		{
			statusIndicator.transform.colorTransform = new openfl.geom.ColorTransform();
		}
	}

	private function positionTextElements()
	{
		// 计算背景所需高度
		var totalHeight = padding * 2;
		totalHeight += fpsText.height;
		totalHeight += delayText.height;
		totalHeight += ramText.height;
		totalHeight += peakText.height;
		totalHeight += objectsText.height;
		totalHeight += versionText.height;
		totalHeight += 12; // 增加额外间距

		// 设置目标尺寸
		targetHeight = totalHeight;
		
		// 定位指示器
		statusIndicator.x = padding;
		statusIndicator.y = padding + (fpsText.height - indicatorSize) / 2;

		// 定位文本
		var textX = padding + indicatorSize + indicatorSpacing;
		var yPos = padding;

		fpsText.x = textX;
		fpsText.y = yPos;
		yPos += fpsText.height + 4; // 增加间距

		delayText.x = textX;
		delayText.y = yPos;
		yPos += delayText.height + 4;

		ramText.x = textX;
		ramText.y = yPos;
		yPos += ramText.height + 4;

		peakText.x = textX;
		peakText.y = yPos;
		yPos += peakText.height + 4;

		objectsText.x = textX;
		objectsText.y = yPos;
		yPos += objectsText.height + 6;

		versionText.x = textX;
		versionText.y = yPos;
	}

	var deltaTimeout:Float = 0.0;

	private override function __enterFrame(deltaTime:Float):Void
	{
		if (!visible)
			return;

		if (Timer.stamp() - lastObjectCountUpdate > 2.0)
		{
			objectCount = countObjects(FlxG.state);
			lastObjectCountUpdate = Timer.stamp();
		}

		// 背景尺寸平滑过渡
		if (currentHeight != targetHeight)
		{
			currentHeight = FlxMath.lerp(currentHeight, targetHeight, lerpSpeed);
			if (Math.abs(currentHeight - targetHeight) < 0.5)
				currentHeight = targetHeight;
				
			drawBackground(0x222222, 0.85, currentWidth, currentHeight);
		}

		if (ClientPrefs.data.fpsRework)
		{
			if (FlxG.stage.window.frameRate != ClientPrefs.data.framerate && FlxG.stage.window.frameRate != FlxG.game.focusLostFramerate)
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate;

			var currentTime = openfl.Lib.getTimer();
			framesCount++;

			if (currentTime >= updateTime)
			{
				var elapsed = currentTime - prevTime;
				currentFPS = Math.ceil((framesCount * 1000) / elapsed);
				framesCount = 0;
				prevTime = currentTime;
				updateTime = currentTime + 500;
			}

			if ((FlxG.updateFramerate >= currentFPS + 5 || FlxG.updateFramerate <= currentFPS - 5)
				&& haxe.Timer.stamp() - lastFramerateUpdateTime >= 1.5
				&& currentFPS >= 30)
			{
				FlxG.updateFramerate = FlxG.drawFramerate = currentFPS;
				lastFramerateUpdateTime = haxe.Timer.stamp();
			}
		}
		else
		{
			final now:Float = haxe.Timer.stamp() * 1000;
			times.push(now);
			while (times[0] < now - 1000)
				times.shift();
			if (deltaTimeout < 50)
			{
				deltaTimeout += deltaTime;
				return;
			}

			currentFPS = times.length < FlxG.updateFramerate ? times.length : FlxG.updateFramerate;
			deltaTimeout = 0.0;
		}

		if (Timer.stamp() - lastFpsUpdateTime > 0.05)
		{
			updateText();
		}
	}

	private function countObjects(state:FlxState, depth:Int = 0):Int
	{
		if (depth > 10)
			return 0;

		var count:Int = 0;

		if (state == null)
			return 0;

		count += countGroupMembers(state.members, depth + 1);

		if (state.subState != null)
		{
			count += countGroupMembers(state.subState.members, depth + 1);
		}

		return count;
	}

	private function countGroupMembers(members:Array<flixel.FlxBasic>, depth:Int = 0):Int
	{
		if (depth > 10)
			return 0;

		var count:Int = 0;

		if (members == null)
			return 0;

		for (member in members)
		{
			if (member != null && member.exists)
			{
				count++;

				if (Std.isOfType(member, flixel.group.FlxGroup.FlxTypedGroup))
				{
					var group:flixel.group.FlxGroup.FlxTypedGroup<flixel.FlxBasic> = cast member;
					count += countGroupMembers(group.members, depth + 1);
				}
			}
		}

		return count;
	}

	inline function get_memoryMegas():Float
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1)
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;

		var spacing = ClientPrefs.data.fpsSpacing;
		var isRight = ClientPrefs.data.fpsPosition.indexOf("RIGHT") != -1;
		var isBottom = ClientPrefs.data.fpsPosition.indexOf("BOTTOM") != -1;

		if (isRight)
		{
			x = FlxG.game.x + FlxG.width - background.width - spacing;
		}
		else
		{
			x = FlxG.game.x + spacing;
		}

		if (isBottom)
		{
			y = FlxG.game.y + FlxG.height - background.height - spacing;
		}
		else
		{
			y = FlxG.game.y + spacing;
		}
	}

	#if cpp
	#if windows
	@:functionCode('
        SYSTEM_INFO osInfo;
        GetSystemInfo(&osInfo);
        switch(osInfo.wProcessorArchitecture)
        {
            case 9: return ::String("x86_64");
            case 5: return ::String("ARM");
            case 12: return ::String("ARM64");
            case 6: return ::String("IA-64");
            case 0: return ::String("x86");
            default: return ::String("Unknown");
        }
    ')
	#elseif (ios || mac)
	@:functionCode('
        const NXArchInfo *archInfo = NXGetLocalArchInfo();
        return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
    ')
	#else
	@:functionCode('
        struct utsname osInfo{}; 
        uname(&osInfo);
        return ::String(osInfo.machine);
    ')
	#end
	@:noCompletion
	private function getArch():String
	{
		return "Unknown";
	}
	#end
}