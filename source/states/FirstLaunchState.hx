package states;

import flixel.FlxSubState;
import flixel.ui.FlxButton;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.effects.FlxFlicker;
import backend.Language;
import backend.ClientPrefs;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

class FirstLaunchState extends MusicBeatState
{
    public static var leftState:Bool = false;

    var currentPage:Int = 0;
    var maxPages:Int = 2;
    var languageButtons:FlxTypedGroup<FlxButton>;
    var flashingButtons:FlxTypedGroup<FlxButton>;
    var texts:FlxTypedSpriteGroup<FlxText>;
    var bg:FlxSprite;
    var titleText:FlxText;
    var nextButton:FlxButton;
    var backButton:FlxButton;

    // 可用语言列表
    var availableLanguages:Array<String> = ["en_us", "zh_cn", "zh_tw"];
    var languageNames:Map<String, String> = [
        "en_us" => "English",
        "zh_cn" => "简体中文",
        "zh_tw" => "繁體中文"
    ];
    var selectedLanguage:String = "en_us";

    var pageGroups:Array<FlxSpriteGroup>; // 存储每个页面的精灵组

    override function create()
    {
        super.create();
        FlxG.mouse.visible = true;
        
        pageGroups = [];
        
        bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        add(bg);

        // 创建标题文本
        titleText = new FlxText(0, 50, FlxG.width, "", 32);
        titleText.setFormat(Language.get('game_font'), 32, FlxColor.WHITE, CENTER);
        add(titleText);

        // 为每个页面创建一个精灵组
        for (i in 0...maxPages) {
            var group = new FlxSpriteGroup();
            group.x = i * FlxG.width;
            pageGroups.push(group);
            add(group);
        }

        // 创建各个按钮组
        languageButtons = new FlxTypedGroup<FlxButton>();
        flashingButtons = new FlxTypedGroup<FlxButton>();
        
        // 创建导航按钮
        createNavigationButtons();

        // 初始化所有页面内容
        initializeAllPages();
        
        ClientPrefs.data.language = selectedLanguage;
        Language.load();
        
        updateText();
    }

    // 新增：获取按钮缩放比例
    private function getButtonScale():Float {
        #if mobile
        return 2.0;
        #else
        return 1.0;
        #end
    }

    // 修改：统一设置按钮大小
    private function setButtonDefaults(button:FlxButton, width:Int, height:Int) {
        var scale = getButtonScale();
        button.setGraphicSize(Std.int(width * scale), Std.int(height * scale));
        button.updateHitbox();
        formatButtonText(button);
    }

    function createNavigationButtons() 
    {
        var buttonWidth = 120;
        var buttonHeight = 40;
        var scale = getButtonScale();
        
        nextButton = new FlxButton(FlxG.width - (buttonWidth * scale) - 30, FlxG.height - (buttonHeight * scale) - 10, "", goToNextPage);
        setButtonDefaults(nextButton, buttonWidth, buttonHeight);
        nextButton.label.text = Language.get("firstlaunch_next");
        add(nextButton);

        backButton = new FlxButton(30, FlxG.height - (buttonHeight * scale) - 10, "", goToPreviousPage);
        setButtonDefaults(backButton, buttonWidth, buttonHeight);
        backButton.label.text = Language.get("firstlaunch_back");
        add(backButton);
    }

    function initializeAllPages() 
    {
        // 初始化语言选择页面
        var buttonWidth = 300;
        var buttonHeight = 40;
        var scale = getButtonScale();
        var yPos = 150;

        for (lang in availableLanguages) {
            var button = new FlxButton(0, yPos, languageNames[lang], function() {
                selectedLanguage = lang;
                updateLanguageButtons();
                goToNextPage();
            });
            setButtonDefaults(button, buttonWidth, buttonHeight);
            button.x = (FlxG.width - button.width) / 2;
            languageButtons.add(button);
            pageGroups[0].add(button);
            yPos = Std.int(yPos + (60 * scale)); // 修复整数类型问题
        }
        updateLanguageButtons();

        // 初始化闪光设置页面
        var yesButton = new FlxButton(
            Std.int(FlxG.width * 0.3 - (75 * scale)), // 修复整数类型问题
            FlxG.height / 2, 
            Language.get("firstlaunch_yes"), 
            function() {
                ClientPrefs.data.flashing = true;
                saveAndExit();
            }
        );
        setButtonDefaults(yesButton, buttonWidth, buttonHeight);
        
        var noButton = new FlxButton(
            Std.int(FlxG.width * 0.7 - (75 * scale)), // 修复整数类型问题
            FlxG.height / 2, 
            Language.get("firstlaunch_no"), 
            function() {
                ClientPrefs.data.flashing = false;
                saveAndExit();
            }
        );
        setButtonDefaults(noButton, buttonWidth, buttonHeight);
        
        flashingButtons.add(yesButton);
        flashingButtons.add(noButton);
        pageGroups[1].add(yesButton);
        pageGroups[1].add(noButton);
    }

    // 修改：统一设置按钮文本格式
    function formatButtonText(button:FlxButton) {
        var scale = getButtonScale();
        var fontSize = Std.parseInt(Language.get('button_text_size')) * 2 * scale;
        
        button.label.setFormat(
            Paths.font(Language.get('game_font')),
            Std.int(fontSize),
            FlxColor.BLACK,
            CENTER
        );
        button.label.fieldWidth = button.width;
        button.label.alignment = CENTER;
        centerButtonText(button);
    }

    // 新增：居中按钮文本
    function centerButtonText(button:FlxButton) {
        button.label.fieldWidth = button.width;
        button.label.x = 0;
        button.label.y = (button.height - button.label.height) / 2;
    }

    function goToNextPage()
    {
        if (currentPage < maxPages - 1) {
            currentPage++;
            for (i in 0...pageGroups.length) {
                var group = pageGroups[i];
                FlxTween.tween(group, {
                    x: (i - currentPage) * FlxG.width
                }, 0.7, {
                    ease: FlxEase.expoOut
                });
            }
            updateText();
            updateNavigationButtons();
        }
    }

    function goToPreviousPage()
    {
        if (currentPage > 0) {
            currentPage--;
            for (i in 0...pageGroups.length) {
                var group = pageGroups[i];
                FlxTween.tween(group, {
                    x: (i - currentPage) * FlxG.width
                }, 0.7, {
                    ease: FlxEase.expoOut
                });
            }
            updateText();
            updateNavigationButtons();
        }
    }

    function updateNavigationButtons() {
        backButton.visible = (currentPage > 0);
        nextButton.visible = (currentPage < maxPages - 1);
    }

    function updateLanguageButtons()
    {
        for (button in languageButtons) {
            button.label.setFormat(Paths.font("unifont-16.0.02.otf"), 
                26,
                0xFF404040  // 设置深灰色
            );
                
            // 修改高亮显示
            if (button.text == languageNames[selectedLanguage]) {
                button.color = 0xFF87CEEB;
                ClientPrefs.data.language = selectedLanguage;
                Language.load();
                updateText();
            } else {
                button.color = 0xFFFFFFFF;
            }
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
            case 0: Language.get("firstlaunch_select");
            case 1: Language.get("flashing_warning_text");
            default: "";
        };

        titleText.font = Paths.font(Language.get('game_font'));
        
        // 更新导航按钮文本
        nextButton.label.text = Language.get("firstlaunch_next");
        backButton.label.text = Language.get("firstlaunch_back");
        centerButtonText(nextButton);
        centerButtonText(backButton);

        // 更新闪光设置按钮
        if (currentPage == 1) {
            var buttons = flashingButtons.members;
            if(buttons.length >= 2) {
                buttons[0].label.text = Language.get("firstlaunch_yes");
                buttons[1].label.text = Language.get("firstlaunch_no");
                
                for(button in buttons) {
                    formatButtonText(button);
                }
            }
        }
    }
}