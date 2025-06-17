package states;

import flixel.FlxSubState;
import flixel.ui.FlxButton;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.effects.FlxFlicker;
import backend.Language;
import backend.ClientPrefs;
import backend.ui.PsychUIButton;

class FirstLaunchState extends MusicBeatState
{
    public static var leftState:Bool = false;

    var currentPage:Int = 0;
    var maxPages:Int = 2;
    var languageButtons:FlxTypedGroup<PsychUIButton>;
    var flashingButtons:FlxTypedGroup<PsychUIButton>;
    var texts:FlxTypedSpriteGroup<FlxText>;
    var bg:FlxSprite;
    var titleText:FlxText;
    var nextButton:PsychUIButton;
    var backButton:PsychUIButton;

    // 可用语言列表
    var availableLanguages:Array<String> = ["en_us", "zh_cn", "zh_tw"];
    var languageNames:Map<String, String> = [
        "en_us" => "English",
        "zh_cn" => "简体中文",
        "zh_tw" => "繁體中文"
    ];
    var selectedLanguage:String = "en_us";

    override function create()
    {
        super.create();
        FlxG.mouse.visible = true;
        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        add(bg);

        texts = new FlxTypedSpriteGroup<FlxText>();
        add(texts);

        // 创建标题
        titleText = new FlxText(0, 50, FlxG.width, "", 32);
        titleText.setFormat(Language.get('game_font'), 32, FlxColor.WHITE, CENTER);
        texts.add(titleText);

        // 创建语言选择按钮组
        languageButtons = new FlxTypedGroup<PsychUIButton>();
        add(languageButtons);

        // 创建闪光设置按钮组
        flashingButtons = new FlxTypedGroup<PsychUIButton>();
        add(flashingButtons);

        // 创建导航按钮
        nextButton = new PsychUIButton(FlxG.width - 150, FlxG.height - 50, "Next", goToNextPage);
		nextButton.resize(120, 40);
        add(nextButton);

        backButton = new PsychUIButton(30, FlxG.height - 50, "Back", goToPreviousPage);
		backButton.resize(120, 40);
        add(backButton);

        // 初始化页面
        updatePage();
    }

    function updatePage()
    {
        // 清除现有内容
        languageButtons.clear();
        flashingButtons.clear();
        texts.clear();
        texts.add(titleText);

        switch (currentPage) {
            case 0: // 语言选择页面
                titleText.text = Language.get("firstlaunch_select");
                
                var yPos = 150;
                for (lang in availableLanguages) {
                    var button = new PsychUIButton(0, yPos, languageNames[lang], function() {
                        selectedLanguage = lang;
                        updateLanguageButtons();
                        goToNextPage(); // 选择语言后自动滑动到下一页
                    });
					button.resize(300, 40);
                    button.x = (FlxG.width - button.width) / 2;
                    languageButtons.add(button);
                    yPos += 60;
                }
                updateLanguageButtons();

            case 1: // 闪光设置页面
                titleText.text = Language.get("flashing_warning_text");
                
                var yesButton = new PsychUIButton(FlxG.width * 0.3 - 75, FlxG.height / 2, Language.get("firstlaunch_yes"), function() {
                    ClientPrefs.data.flashing = true;
                    saveAndExit();
                });
				yesButton.resize(120, 40);
                
                var noButton = new PsychUIButton(FlxG.width * 0.7 - 75, FlxG.height / 2, Language.get("firstlaunch_no"), function() {
                    ClientPrefs.data.flashing = false;
                    saveAndExit();
                });
				noButton.resize(120, 40);
                
                flashingButtons.add(yesButton);
                flashingButtons.add(noButton);
                
                var infoText = new FlxText(0, FlxG.height / 2 + 60, FlxG.width, 
                    Language.get("firstlaunch_warning"));
                infoText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER);
                texts.add(infoText);
        }
        
        // 更新导航按钮可见性
        backButton.visible = (currentPage > 0);
        nextButton.visible = (currentPage < maxPages - 1);
    }

    function updateLanguageButtons()
    {
        for (button in languageButtons) {
            button.text.font = Paths.font("ResourceHanRoundedCN-Bold.ttf");
            button.text.size = Std.parseInt(Language.get('button_text_size')) * 2;
            button.color = (button.label == languageNames[selectedLanguage]) ? 
                0xFF87CEEB : // 选中颜色
                0xFFFFFFFF;  // 默认颜色
        }
    }

    function goToNextPage()
    {
        if (currentPage < maxPages - 1) {
            currentPage++;
            updatePage();
        }
    }

    function goToPreviousPage()
    {
        if (currentPage > 0) {
            currentPage--;
            updatePage();
        }
    }

    function saveAndExit()
    {
        // 保存语言设置
        ClientPrefs.data.language = selectedLanguage;
        
        // 保存所有设置
        ClientPrefs.saveSettings();
        
        leftState = true;
        FlxTransitionableState.skipNextTransIn = true;
        FlxTransitionableState.skipNextTransOut = true;
        
        // 加载语言
        Language.load();
        
        // 更新文本
        updateText();
        
        // 切换到标题界面
        MusicBeatState.switchState(new TitleState());
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        // 支持键盘导航
        if (FlxG.keys.justPressed.RIGHT) goToNextPage();
        if (FlxG.keys.justPressed.LEFT) goToPreviousPage();
    }

    function updateText() {
        titleText.text = switch (currentPage) {
            case 0:
                Language.get("firstlaunch_select");
            case 1:
                Language.get("firstlaunch_flashing");
            default:
                "";
        };

        nextButton.label = Language.get("firstlaunch_next");
        backButton.label = Language.get("firstlaunch_back");

        for (button in languageButtons) {
            for (lang in availableLanguages) {
                if (languageNames[lang] == button.label) {
                    button.label = languageNames[lang];
                    break;
                }
            }
        }

        if (currentPage == 1) {
            for (button in flashingButtons) {
                button.label = if (button.label == Language.get("firstlaunch_yes")) Language.get("firstlaunch_yes") else Language.get("firstlaunch_no");
            }
        }
    }
}