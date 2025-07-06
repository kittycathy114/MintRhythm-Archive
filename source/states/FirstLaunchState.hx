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
import flixel.FlxG;
import flixel.util.FlxTimer;

class FirstLaunchState extends MusicBeatState
{
    public static var leftState:Bool = false;

    var currentPage:Int = 0;
    var maxPages:Int = 2;
    var languageButtons:FlxTypedGroup<FlxButton>;
    var flashingButtons:FlxTypedGroup<FlxButton>;
    var bg:FlxSprite;
    var titleText:FlxText;
    
    // 反馈文本
    var feedbackText:FlxText;
    var feedbackTween:FlxTween;
    
    // 可用语言列表
    var availableLanguages:Array<String> = ["en_us", "zh_cn", "zh_tw"];
    var languageNames:Map<String, String> = [
        "en_us" => "English",
        "zh_cn" => "简体中文",
        "zh_tw" => "繁體中文"
    ];
    var selectedLanguage:String = "en_us";

    var pageGroups:Array<FlxSpriteGroup>; // 存储每个页面的精灵组
    var inTransition:Bool = false; // 防止在动画期间进行交互

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

        // 创建反馈文本（初始隐藏）
        feedbackText = new FlxText(0, 0, FlxG.width, "", 24);
        feedbackText.setFormat(Language.get('game_font'), 24, FlxColor.WHITE, CENTER);
        feedbackText.alpha = 0;
        feedbackText.visible = false;
        add(feedbackText);

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
        
        // 初始化所有页面内容
        initializeAllPages();
        
        // 设置默认语言
        ClientPrefs.data.language = selectedLanguage;
        Language.load();
        
        updateText();
    }

    // 获取按钮缩放比例
    private function getButtonScale():Float {
        #if mobile
        return 2.0;
        #else
        return 1.0;
        #end
    }

    // 统一设置按钮大小
    private function setButtonDefaults(button:FlxButton, width:Int, height:Int) {
        var scale = getButtonScale();
        button.setGraphicSize(Std.int(width * scale), Std.int(height * scale));
        button.updateHitbox();
        formatButtonText(button);
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
                if (inTransition) return;
                
                selectedLanguage = lang;
                updateLanguageButtons();
                
                // 显示语言设置成功的反馈
                showLanguageFeedback();
            });
            setButtonDefaults(button, buttonWidth, buttonHeight);
            button.x = (FlxG.width - button.width) / 2;
            languageButtons.add(button);
            pageGroups[0].add(button);
            yPos = Std.int(yPos + (60 * scale));
        }
        updateLanguageButtons();

        // 初始化闪光设置页面
        var buttonWidth = 300;
        var buttonHeight = 40;
        var scale = getButtonScale();
        var yPos = FlxG.height / 2;
        
        var yesButton = new FlxButton(
            (FlxG.width - buttonWidth * scale) / 2,
            yPos - (60 * scale),
            Language.get("firstlaunch_yes"),
            function() {
                if (inTransition) return;
                
                ClientPrefs.data.flashing = true;
                saveAndExit();
            }
        );
        setButtonDefaults(yesButton, buttonWidth, buttonHeight);
        
        var noButton = new FlxButton(
            (FlxG.width - buttonWidth * scale) / 2,
            yPos + (60 * scale),
            Language.get("firstlaunch_no"),
            function() {
                if (inTransition) return;
                
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

    // 显示语言设置成功的反馈动画
    function showLanguageFeedback()
    {
        inTransition = true;
        
        // 禁用所有按钮
        for (button in languageButtons) {
            button.active = false;
        }
        
        // 设置反馈文本
        feedbackText.text = Language.get("firstlaunch_language_set") + " " + languageNames[selectedLanguage];
        feedbackText.font = Paths.font(Language.get('game_font'));
        feedbackText.size = 28;
        feedbackText.updateHitbox();
        
        // 初始位置和状态
        feedbackText.x = 0;
        feedbackText.y = FlxG.height / 2 - feedbackText.height / 2;
        feedbackText.alpha = 0;
        feedbackText.visible = true;
        
        // 渐显动画
        FlxTween.tween(feedbackText, {alpha: 1}, 0.5, {
            ease: FlxEase.quadOut,
            onComplete: function(twn:FlxTween) {
                // 停留1秒
                new FlxTimer().start(1, function(tmr:FlxTimer) {
                    // 上移并渐隐
                    feedbackTween = FlxTween.tween(feedbackText, {
                        y: feedbackText.y - 100,
                        alpha: 0
                    }, 0.8, {
                        ease: FlxEase.quadOut,
                        onComplete: function(twn:FlxTween) {
                            feedbackText.visible = false;
                            goToNextPage();
                        }
                    });
                });
            }
        });
    }

    // 统一设置按钮文本格式
    function formatButtonText(button:FlxButton) {
        var scale = getButtonScale();
        var fontSize = 24 * scale;
        
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

    // 居中按钮文本
    function centerButtonText(button:FlxButton) {
        button.label.fieldWidth = button.width;
        button.label.x = 0;
        button.label.y = (button.height - button.label.height) / 2;
    }

    function goToNextPage()
    {
        if (currentPage < maxPages - 1) {
            currentPage++;
            
            // 页面切换动画
            for (i in 0...pageGroups.length) {
                var group = pageGroups[i];
                FlxTween.tween(group, {
                    x: (i - currentPage) * FlxG.width
                }, 1.0, {
                    ease: FlxEase.quadOut,
                    onComplete: function(twn:FlxTween) {
                        inTransition = false;
                    }
                });
            }
            
            updateText();
        }
    }

    function updateLanguageButtons()
    {
        for (button in languageButtons) {
            // 重置所有按钮颜色
            button.color = 0xFFFFFFFF;
            
            // 高亮显示选中按钮
            if (button.text == languageNames[selectedLanguage]) {
                // 使用更明显的选中效果
                FlxFlicker.flicker(button, 0, 0.1, true, true);
                button.label.color = FlxColor.WHITE;
                button.color = 0xFF2E86C1; // 蓝色
            } else {
                button.label.color = FlxColor.BLACK;
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
        
        // 添加退出动画
        FlxTween.tween(bg, {alpha: 0}, 0.8, {
            ease: FlxEase.quadOut,
            onComplete: function(twn:FlxTween) {
                // 切换到标题界面
                MusicBeatState.switchState(new TitleState());
            }
        });
    }

    function updateText() {
        titleText.text = switch (currentPage) {
            case 0: Language.get("firstlaunch_select");
            case 1: Language.get("flashing_warning_text");
            default: "";
        };

        titleText.font = Paths.font(Language.get('game_font'));
        titleText.updateHitbox();
        titleText.screenCenter(X);

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