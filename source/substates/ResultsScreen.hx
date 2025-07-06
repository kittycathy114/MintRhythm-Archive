package substates;

import haxe.Exception;
/*#if FEATURE_STEPMANIA
import smTools.SMFile;
#end*/
#if FEATURE_FILESYSTEM
import sys.FileSystem;
import sys.io.File;
#end

import states.StoryMenuState;
import states.FreeplayState;
import states.PlayState;
import backend.Rating;
import backend.ClientPrefs;

import openfl.geom.Matrix;
import openfl.display.BitmapData;
import flixel.system.FlxSound;
import flixel.util.FlxAxes;
import flixel.FlxSubState;
import flixel.input.FlxInput;
import flixel.input.keyboard.FlxKey;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import lime.app.Application;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.input.FlxKeyManager;

import backend.ui.OFLSprite;
import backend.HitGraph;

using StringTools;

class ResultsScreen extends FlxSubState
{
	public var background:FlxSprite;
	public var text:FlxText;

	public var anotherBackground:FlxSprite;
	public var graph:HitGraph;
	public var graphSprite:OFLSprite;

	public var comboText:FlxText;
	public var contText:FlxText;
	public var settingsText:FlxText;

	public var music:FlxSound;

	public var graphData:BitmapData;

	public var ranking:String;
	public var accuracy:String;

	override function create()
	{
		background = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		background.scrollFactor.set();
		add(background);

		//if (!PlayState.inResults)
		{
			music = new FlxSound().loadEmbedded(Paths.music('breakfast'), true, true);
			music.volume = 0;
			music.play(false, FlxG.random.int(0, Std.int(music.length / 2)));
			FlxG.sound.list.add(music);
		}

		background.alpha = 0;

		text = new FlxText(20, -55, 0, "Song Cleared!");
		text.size = 34;
		text.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 4, 1);
		text.color = FlxColor.WHITE;
		text.scrollFactor.set();
		add(text);

		var score = PlayState.instance.songScore;
		if (PlayState.isStoryMode)
		{
			score = PlayState.campaignScore;
			text.text = "Week Cleared!";
		}

		/*var sicks = PlayState.isStoryMode ? PlayState.campaignSicks : PlayState.sicks;
		var goods = PlayState.isStoryMode ? PlayState.campaignGoods : PlayState.goods;
		var bads = PlayState.isStoryMode ? PlayState.campaignBads : PlayState.bads;
		var shits = PlayState.isStoryMode ? PlayState.campaignShits : PlayState.shits;

		comboText = new FlxText(20, -75, 0,
			//'Judgements:\nSicks - ${sicks}\nGoods - ${goods}\nBads - ${bads}\n\nCombo Breaks: ${(PlayState.isStoryMode ? PlayState.campaignMisses : PlayState.misses)}\nHighest Combo: ${PlayState.highestCombo + 1}\nScore: ${PlayState.instance.songScore}\nAccuracy: ${HelperFunctions.truncateFloat(PlayState.instance.accuracy, 2)}%\n\n${Ratings.GenerateLetterRank(PlayState.instance.accuracy)}\nRate: ${PlayState.songMultiplier}x\n\n${!PlayState.loadRep ? "\nF1 - Replay song" : ""}
			'Judgements:\nSicks - ${sicks}\nGoods - ${goods}\nBads - ${bads}\n\nCombo Breaks: ${(PlayState.isStoryMode ? PlayState.campaignMisses : PlayState.misses)}\nScore: ${PlayState.instance.songScore}\nAccuracy: ${PlayState.instance.accuracy}%\n\n${Ratings.GenerateLetterRank(PlayState.instance.accuracy)}\nRate: ${PlayState.songMultiplier}x\n\n${!PlayState.loadRep ? "\nF1 - Replay song" : ""}
        ');
		comboText.size = 28;
		comboText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 4, 1);
		comboText.color = FlxColor.WHITE;
		comboText.scrollFactor.set();
		add(comboText);

		contText = new FlxText(FlxG.width - 475, FlxG.height + 50, 0, 'Press ${KeyBinds.gamepad ? 'A' : 'ENTER'} to continue.');
		contText.size = 28;
		contText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 4, 1);
		contText.color = FlxColor.WHITE;
		contText.scrollFactor.set();
		add(contText);*/

		// 统计判定数量
		var perfects = 0;
		var sicks = 0;
		var goods = 0;
		var bads = 0;
		var shits = 0;
		for (r in PlayState.instance.ratingsData) {
    		switch (r.name) {
        		case "perfect": perfects = r.hits;
        		case "sick": sicks = r.hits;
        		case "good": goods = r.hits;
        		case "bad": bads = r.hits;
        		case "shit": shits = r.hits;
    		}
		}

		// 组合文本
		/*comboText = new FlxText(20, -75, 0,
    		//'Judgements:\nSicks - ${sicks}\nGoods - ${goods}\nBads - ${bads}\nShits - ${shits}\n\nCombo Breaks: ${PlayState.instance.songMisses}\nScore: ${PlayState.instance.songScore}\nAccuracy: ${Std.string(Math.floor(PlayState.instance.ratingPercent * 10000) / 100)}%\n\n${Rating.GenerateLetterRank(PlayState.instance.ratingPercent * 100)}\nRate: ${PlayState.songMultiplier}x\n\n${!PlayState.loadRep ? "\nF1 - Replay song" : ""}'
    		'Judgements:\n${!ClientPrefs.data.rmPerfect ? 'Perfects - ${perfects}\n' : ""}Sicks - ${sicks}\nGoods - ${goods}\nBads - ${bads}\nShits - ${shits}\n\nCombo Breaks: ${PlayState.instance.songMisses}\nScore: ${PlayState.instance.songScore}\nAccuracy: ${Std.string(Math.floor(PlayState.instance.ratingPercent * 10000) / 100)}%\n\n\nRate: ${PlayState.instance.songSpeed} x'
		);
		comboText.size = 28;
		comboText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 4, 1);
		comboText.color = FlxColor.WHITE;
		comboText.scrollFactor.set();
		add(comboText);*/

		var comboStr = 'Judgements:\n'
    + (!ClientPrefs.data.rmPerfect ? 'Perfects - ${perfects}\n' : "")
    + 'Sicks - ${sicks}\n'
    + 'Goods - ${goods}\n'
    + 'Bads - ${bads}\n'
    + 'Shits - ${shits}\n\n'
    + 'Combo Breaks: ${PlayState.instance.songMisses}\n'
    + 'Score: ${PlayState.instance.songScore}\n'
    + 'Accuracy: ${Std.string(Math.floor(PlayState.instance.ratingPercent * 10000) / 100)}%\n\n\n'
    + 'Rate: ${PlayState.instance.songSpeed} x';

comboText = new FlxText(20, -75, 0, comboStr);
comboText.size = 28;
comboText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 4, 1);
comboText.color = FlxColor.WHITE;
comboText.scrollFactor.set();

// 为每个判定添加不同颜色
var idx = 0;
if (!ClientPrefs.data.rmPerfect) {
    idx = comboStr.indexOf('Perfects');
    comboText.addFormat(new flixel.text.FlxTextFormat(0xFFFFC0CB), idx, idx + ('Perfects - ${perfects}'.length)); // 金色
}
idx = comboStr.indexOf('Sicks');
comboText.addFormat(new flixel.text.FlxTextFormat(0xFF87CEFA), idx, idx + ('Sicks - ${sicks}'.length)); // 绿色
idx = comboStr.indexOf('Goods');
comboText.addFormat(new flixel.text.FlxTextFormat(0xFF66CDAA), idx, idx + ('Goods - ${goods}'.length)); // 蓝色
idx = comboStr.indexOf('Bads');
comboText.addFormat(new flixel.text.FlxTextFormat(0xFFF4A460), idx, idx + ('Bads - ${bads}'.length)); // 黄色
idx = comboStr.indexOf('Shits');
comboText.addFormat(new flixel.text.FlxTextFormat(0xFFFF4500), idx, idx + ('Shits - ${shits}'.length)); // 红色

add(comboText);

		// contText 简单写法
		contText = new FlxText(FlxG.width - 475, FlxG.height + 50, 0, 'Press ENTER to continue.');
		contText.size = 28;
		contText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 4, 1);
		contText.color = FlxColor.WHITE;
		contText.scrollFactor.set();
		add(contText);

		anotherBackground = new FlxSprite(FlxG.width - 500, 45).makeGraphic(450, 240, FlxColor.BLACK);
		anotherBackground.scrollFactor.set();
		anotherBackground.alpha = 0;
		add(anotherBackground);

		graph = new HitGraph(FlxG.width - 500, 45, 495, 240);
		graph.alpha = 0;

		graphSprite = new OFLSprite(FlxG.width - 510, 45, 460, 240, graph);

		graphSprite.scrollFactor.set();
		graphSprite.alpha = 0;

		add(graphSprite);

		/*var sicks = PlayState.sicks;
		var goods = PlayState.goods;
*/
		if (sicks == Math.POSITIVE_INFINITY)
			sicks = 0;
		if (goods == Math.POSITIVE_INFINITY)
			goods = 0;

		var mean:Float = 0;

		/*for (i in 0...PlayState.rep.replay.songNotes.length)
		{
			// 0 = time
			// 1 = length
			// 2 = type
			// 3 = diff
			var obj = PlayState.rep.replay.songNotes[i];
			// judgement
			var obj2 = PlayState.rep.replay.songJudgements[i];

			var obj3 = obj[0];

			var diff = obj[3];
			var judge = obj2;
			if (diff != (166 * Math.floor((PlayState.rep.replay.sf / 60) * 1000) / 166))
				mean += diff;
			//if (obj[1] != -1)
				//graph.addToHistory(diff / PlayState.songMultiplier, judge, obj3 / PlayState.songMultiplier);
		}

		if (sicks == Math.POSITIVE_INFINITY || sicks == Math.NaN)
			sicks = 0;
		if (goods == Math.POSITIVE_INFINITY || goods == Math.NaN)
			goods = 0;

		//graph.update();

		mean = HelperFunctions.truncateFloat(mean / PlayState.rep.replay.songNotes.length, 2);*/
		var averageMs:Float = 0;
		//if (PlayState.instance.songHits > 0)
    	@:privateAccess
		averageMs = PlayState.instance.allNotesMs / PlayState.instance.songHits;

		settingsText = new FlxText(20, FlxG.height + 50, 0,
    		'Avg: ${Math.round(averageMs * 100) / 100}ms (${!ClientPrefs.data.rmPerfect ? "PERFECT:" + ClientPrefs.data.perfectWindow + "ms," : ""}SICK:${ClientPrefs.data.sickWindow}ms,GOOD:${ClientPrefs.data.goodWindow}ms,BAD:${ClientPrefs.data.badWindow}ms)'
		);
		settingsText.size = 16;
		settingsText.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 2, 1);
		settingsText.color = FlxColor.WHITE;
		settingsText.scrollFactor.set();
		add(settingsText);

		FlxTween.tween(background, {alpha: 0.5}, 0.5);
		FlxTween.tween(text, {y: 20}, 0.5, {ease: FlxEase.expoInOut});
		FlxTween.tween(comboText, {y: 145}, 0.5, {ease: FlxEase.expoInOut});
		FlxTween.tween(contText, {y: FlxG.height - 45}, 0.5, {ease: FlxEase.expoInOut});
		FlxTween.tween(settingsText, {y: FlxG.height - 35}, 0.5, {ease: FlxEase.expoInOut});
		FlxTween.tween(anotherBackground, {alpha: 0.6}, 0.5, {
			onUpdate: function(tween:FlxTween)
			{
				graph.alpha = FlxMath.lerp(0, 1, tween.percent);
				graphSprite.alpha = FlxMath.lerp(0, 1, tween.percent);
			}
		});

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];

		super.create();
	}

	var frames = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (music != null)
			if (music.volume < 0.5)
				music.volume += 0.01 * elapsed;

		// keybinds

		/*if (PlayerSettings.player1.controls.ACCEPT)
		{
			if (music != null)
				music.fadeOut(0.3);

			PlayState.loadRep = false;
			PlayState.stageTesting = false;
			PlayState.rep = null;

			#if !switch
			Highscore.saveScore(PlayState.SONG.songId, Math.round(PlayState.instance.songScore), PlayState.storyDifficulty);
			Highscore.saveCombo(PlayState.SONG.songId, Ratings.GenerateLetterRank(PlayState.instance.accuracy), PlayState.storyDifficulty);
			#end

			if (PlayState.isStoryMode)
			{
				FlxG.sound.playMusic(Paths.music('freakyMenu'));
				Conductor.changeBPM(102);
				FlxG.switchState(new MainMenuState());
			}
			else
				FlxG.switchState(new FreeplayState());
			PlayState.instance.clean();
		}*/

		/*if (FlxG.keys.justPressed.F1 && !PlayState.loadRep)
		{
			PlayState.rep = null;

			PlayState.loadRep = false;
			PlayState.stageTesting = false;

			#if !switch
			Highscore.saveScore(PlayState.SONG.songId, Math.round(PlayState.instance.songScore), PlayState.storyDifficulty);
			Highscore.saveCombo(PlayState.SONG.songId, Ratings.GenerateLetterRank(PlayState.instance.accuracy), PlayState.storyDifficulty);
			#end

			if (music != null)
				music.fadeOut(0.3);

			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = PlayState.storyDifficulty;
			LoadingState.loadAndSwitchState(new PlayState());
			PlayState.instance.clean();
		}*/

		if (FlxG.keys.justPressed.ENTER)
    	{
        	/*if (PlayState.isStoryMode)
        	{
            	FlxG.sound.playMusic(Paths.music('freakyMenu'));
            	Conductor.set_bpm(102);
            	FlxG.switchState(new StoryMenuState());
        	}
        	else*/
        	{
				trace('WENT BACK TO FREEPLAY??');
				#if DISCORD_ALLOWED DiscordClient.resetClientID(); #end
        		PlayState.instance.canResync = false;
				PlayState.changedDifficulty = false;
        		Mods.loadTopMod();
        		FlxG.sound.playMusic(Paths.music('freakyMenu'));
        		MusicBeatState.switchState(new FreeplayState());
			}
        	close(); // 关闭substate
    	}
	}
}
