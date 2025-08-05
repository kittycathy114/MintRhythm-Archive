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
@:cppFileCode('#include <windows.h>
#include <psapi.h>')
@:buildXml('
<target id="haxe">
    <lib name="psapi.lib" />
</target>
')
#elseif (ios || mac)
@:cppFileCode('#include <mach-o/arch.h>
#include <mach/mach.h>
#include <mach/mach_init.h>
#include <mach/task.h>')
#else
@:headerInclude('sys/utsname.h')
@:headerInclude('sys/sysinfo.h')
@:headerInclude('cstdio')
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

	// 布局参数
	private var padding:Float = 8;
	private var cornerRadius:Float = 8;

	// 性能优化变量
	private var lastFpsUpdateTime:Float = 0;
	private var lastRamUpdateTime:Float = 0;
	private var lastObjectsUpdateTime:Float = 0;
	private var lastBackgroundUpdateTime:Float = 0;
	
	// 移除平滑过渡效果
	private var targetWidth:Float = 200;
	private var targetHeight:Float = 120;
	
	// 颜色缓存，减少颜色计算
	private var fpsColor:Int = 0xFF66FF66;
	private var ramColor:Int = 0xFF66AAFF;
	private var peakColor:Int = 0xFFFFA500;
	private var delayColor:Int = 0xFFFFFF66;
	private var objectsColor:Int = 0xFF00FF00;

	// 修复：添加缺失的变量声明
	@:noCompletion private var lastExGameVersion:Bool;
	@:noCompletion private var lastShowRunningOS:Bool;

	public var fontName:String = Paths.font("vcr.ttf");

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		// 创建半透明背景 - 简化
		background = new Shape();
		drawBackground(0x222222, 0.85, targetWidth, targetHeight);
		addChild(background);

		// 创建文本字段 - 使用默认颜色，减少颜色变化
		fpsText = createTextField(20, fpsColor, true);
		ramText = createTextField(16, ramColor);
		peakText = createTextField(16, peakColor);
		delayText = createTextField(16, delayColor);
		versionText = createTextField(12, 0xCCCCCC);
		objectsText = createTextField(14, objectsColor);

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
		lastBackgroundUpdateTime = Timer.stamp();
		
		// 初始定位
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

		// 移除边框以减少绘制调用
		// background.graphics.lineStyle(1, 0xFFFFFF, 0.2);
		// background.graphics.drawRoundRect(0, 0, width, height, cornerRadius);
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

		// 检查设置是否变化 - 减少检查频率
		if (currentTime - lastBackgroundUpdateTime > 1.0 && 
			(ClientPrefs.data.exgameversion != lastExGameVersion || ClientPrefs.data.showRunningOS != lastShowRunningOS))
		{
			lastExGameVersion = ClientPrefs.data.exgameversion;
			lastShowRunningOS = ClientPrefs.data.showRunningOS;
			updateVersionText();
			lastBackgroundUpdateTime = currentTime;
		}

		// 更新内存峰值
		if (memory > memoryPeakMegas)
		{
			memoryPeakMegas = memory;
		}

		// 降低FPS更新频率（每秒最多10次）
		if (currentTime - lastFpsUpdateTime > 0.1)
		{
			// 更新 FPS 文本
			fpsText.text = 'FPS: $currentFPS';

			// 简化颜色变化逻辑 - 只在显著变化时更新颜色
			if (currentFPS < FlxG.stage.window.frameRate * 0.5)
			{
				if (fpsColor != 0xFFFF4444) {
					fpsColor = 0xFFFF4444;
					fpsText.textColor = fpsColor;
				}
			}
			else if (currentFPS < FlxG.stage.window.frameRate * 0.75)
			{
				if (fpsColor != 0xFFFFFF66) {
					fpsColor = 0xFFFFFF66;
					fpsText.textColor = fpsColor;
				}
			}
			else
			{
				if (fpsColor != 0xFF66FF66) {
					fpsColor = 0xFF66FF66;
					fpsText.textColor = fpsColor;
				}
			}

			lastFpsUpdateTime = currentTime;
		}

		// 降低RAM更新频率（每秒最多2次）
		if (currentTime - lastRamUpdateTime > 0.5)
		{
			// 更新内存信息
			ramText.text = 'RAM: ${flixel.util.FlxStringUtil.formatBytes(memory)}';
			
			// 简化颜色变化
			if (memory > 1024 * 1024 * 500 && ramColor != 0xFFFF6666) {
				ramColor = 0xFFFF6666;
				ramText.textColor = ramColor;
			} else if (memory <= 1024 * 1024 * 500 && ramColor != 0xFF66AAFF) {
				ramColor = 0xFF66AAFF;
				ramText.textColor = ramColor;
			}

			// 更新内存峰值
			peakText.text = 'MEM Peak: ${flixel.util.FlxStringUtil.formatBytes(memoryPeakMegas)}';
			// 移除峰值颜色变化 - 使用固定颜色

			lastRamUpdateTime = currentTime;
		}

		// 降低延迟更新频率（每秒最多5次）
		if (currentTime - lastDelayUpdateTime > 0.2)
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
			
			// 简化颜色变化
			if (currentDelay > 16.7 && delayColor != 0xFFFF6666) {
				delayColor = 0xFFFF6666;
				delayText.textColor = delayColor;
			} else if (currentDelay <= 16.7 && delayColor != 0xFFFFFF66) {
				delayColor = 0xFFFFFF66;
				delayText.textColor = delayColor;
			}

			lastDelayUpdateTime = currentTime;
		}

		// 降低对象计数更新频率（每秒最多1次）
		if (currentTime - lastObjectsUpdateTime > 1.0)
		{
			// 更新对象数量
			objectsText.text = 'Objects: $objectCount';
			
			// 简化颜色变化
			if (objectCount > 2000 && objectsColor != 0xFFFF6666) {
				objectsColor = 0xFFFF6666;
				objectsText.textColor = objectsColor;
			} else if (objectCount <= 2000 && objectsColor != 0xFF00FF00) {
				objectsColor = 0xFF00FF00;
				objectsText.textColor = objectsColor;
			}

			lastObjectsUpdateTime = currentTime;
		}

		// 减少背景更新频率
		if (currentTime - lastBackgroundUpdateTime > 1.0)
		{
			positionTextElements();
			lastBackgroundUpdateTime = currentTime;
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
		totalHeight += 6;

		// 设置目标尺寸 - 移除平滑过渡
		targetHeight = totalHeight;
		drawBackground(0x222222, 0.85, targetWidth, targetHeight);
		
		// 定位文本
		var textX = padding;
		var yPos = padding;

		fpsText.x = textX;
		fpsText.y = yPos;
		yPos += fpsText.height + 2;

		delayText.x = textX;
		delayText.y = yPos;
		yPos += delayText.height + 2;

		ramText.x = textX;
		ramText.y = yPos;
		yPos += ramText.height + 2;

		peakText.x = textX;
		peakText.y = yPos;
		yPos += peakText.height + 2;

		objectsText.x = textX;
		objectsText.y = yPos;
		yPos += objectsText.height + 3;

		versionText.x = textX;
		versionText.y = yPos;
	}

	var deltaTimeout:Float = 0.0;

	private override function __enterFrame(deltaTime:Float):Void
	{
		if (!visible)
			return;

		// 降低对象计数频率（每5秒一次）
		if (Timer.stamp() - lastObjectCountUpdate > 5.0)
		{
			objectCount = countObjects(FlxG.state);
			lastObjectCountUpdate = Timer.stamp();
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

		// 降低整体更新频率
		if (Timer.stamp() - lastFpsUpdateTime > 0.1)
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

				// 优化：跳过不需要计数的对象类型
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
	{
		#if cpp
			#if windows
				return getWindowsMemoryUsage();
			#elseif (ios || mac)
				return getMacMemoryUsage();
			#elseif linux
				return getLinuxMemoryUsage();
			#else
				return getFallbackMemoryUsage();
			#end
		#else
			return getFallbackMemoryUsage();
		#end
	}

	#if cpp
	#if windows
	@:functionCode('
		PROCESS_MEMORY_COUNTERS_EX pmc;
		if (GetProcessMemoryInfo(GetCurrentProcess(), (PROCESS_MEMORY_COUNTERS*)&pmc, sizeof(pmc)))
			return (double)pmc.WorkingSetSize;
		else
			return 0;
	')
	private function getWindowsMemoryUsage():Float
	{
		return 0;
	}
	#end

	#if (ios || mac)
	@:functionCode('
		task_vm_info_data_t vmInfo;
		mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
		if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&vmInfo, &count) == KERN_SUCCESS)
			return (double)vmInfo.phys_footprint;
		else
			return 0;
	')
	private function getMacMemoryUsage():Float
	{
		return 0;
	}
	#end

	#if linux
	@:functionCode('
		FILE* file = fopen("/proc/self/status", "r");
		if (file) {
			char line[128];
			unsigned long vmRSS = 0;
			
			while (fgets(line, sizeof(line), file) {
				if (strncmp(line, "VmRSS:", 6) == 0) {
					vmRSS = parseLine(line);
					break;
				}
			}
			fclose(file);
			return vmRSS * 1024.0;
		}
		return 0;
	')
	private function getLinuxMemoryUsage():Float
	{
		return 0;
	}
	
	@:functionCode('
		char* p = line;
		while (*p < \'0\' || *p > \'9\') p++;
		return strtoul(p, NULL, 10);
	')
	private function parseLine(line:cpp.ConstCharStar):cpp.UInt64
	{
		return 0;
	}
	#end
	#end

	private function getFallbackMemoryUsage():Float
	{
		#if sys
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#else
		return openfl.system.System.totalMemory;
		#end
	}

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