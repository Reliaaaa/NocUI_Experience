using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Xaml.Media.Imaging;
using Microsoft.UI.Text;
using Windows.UI;

namespace NotchUI;

public sealed partial class MainWindow
{
    private Slider WidthSlider = null!, HeightSlider = null!, RadiusSlider = null!, OpacitySlider = null!, DurationSlider = null!;
    private TextBlock WidthLabel = null!, HeightLabel = null!, RadiusLabel = null!, OpacityLabel = null!, DurationLabel = null!, PageTitle = null!, PageDescription = null!, PreviewText = null!;
    private StackPanel AppearancePage = null!, WidgetsPage = null!, AboutPage = null!, BehaviorPage = null!, AnimationsPage = null!;
    private ToggleSwitch ClockToggle = null!, BatteryToggle = null!, MediaToggle = null!, HoverToggle = null!;
    private ColorPicker BackgroundPicker = null!;
    private Border PreviewPill = null!;
    private InfoBar SettingsError = null!;

    private static TextBlock Label(string text, double size = 14) => new() { Text = text, FontSize = size, TextWrapping = TextWrapping.Wrap };
    private static StackPanel Panel(double spacing = 12) => new() { Spacing = spacing };
    private static Border Card(UIElement child) => new() { Background = (Brush)Application.Current.Resources["CardBackgroundFillColorDefaultBrush"], CornerRadius = new CornerRadius(12), Padding = new Thickness(20), Child = child };
    private static TextBlock Heading(string text) => new() { Text = text, FontSize = 20, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap };
    private static Slider MakeSlider(double min, double max, double step, string name)
    {
        var slider = new Slider { Minimum = min, Maximum = max, StepFrequency = step };
        AutomationProperties.SetName(slider, name);
        return slider;
    }
    private void InitializeComponent()
    {
        Title = "NotchUI Settings";
        var nav = new NavigationView { Background = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0)), IsSettingsVisible = false, IsBackButtonVisible = NavigationViewBackButtonVisible.Collapsed };
        var brand = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 12, Margin = new Thickness(12, 12, 0, 20) };
        brand.Children.Add(new Image { Source = new BitmapImage(new Uri("ms-appx:///Assets/Square44x44Logo.png")), Width = 38, Height = 38 });
        var brandText = Panel(0); brandText.Children.Add(Heading("NotchUI")); brandText.Children.Add(Label("Windows desktop", 12)); brand.Children.Add(brandText); nav.PaneHeader = brand;
        NavigationViewItem Item(string text, string tag, Symbol icon) => new() { Content = text, Tag = tag, Icon = new SymbolIcon(icon) };
        var appearanceItem = Item("General & Appearance", "appearance", Symbol.Setting);
        nav.MenuItems.Add(appearanceItem); nav.MenuItems.Add(Item("Notch Widgets", "widgets", Symbol.AllApps));
        nav.MenuItems.Add(Item("Gestures & Behavior", "behavior", Symbol.Edit)); nav.MenuItems.Add(Item("Animations", "animations", Symbol.Play)); nav.MenuItems.Add(Item("About", "about", Symbol.Help));
        var root = Panel(20); root.Padding = new Thickness(32, 28, 32, 48); root.MaxWidth = 940;
        PageTitle = new TextBlock { Text = "Appearance & hardware bounds", FontSize = 30, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap };
        PageDescription = Label("Personalize your notch. Changes apply immediately."); PageDescription.Opacity = 0.7;
        SettingsError = new InfoBar { Severity = InfoBarSeverity.Warning, IsOpen = false };
        root.Children.Add(PageTitle); root.Children.Add(PageDescription); root.Children.Add(SettingsError);
        AppearancePage = Panel(16); WidgetsPage = Panel(); AboutPage = Panel(); BehaviorPage = Panel(); AnimationsPage = Panel();
        WidgetsPage.Visibility = AboutPage.Visibility = BehaviorPage.Visibility = AnimationsPage.Visibility = Visibility.Collapsed;
        var preview = Panel(); preview.Children.Add(Heading("Live preview")); preview.Children.Add(Label("A preview of the notch on your screen"));
        PreviewText = new TextBlock { Text = "NotchUI  •  Live preview", HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis };
        PreviewPill = new Border { Width = 320, Height = 34, CornerRadius = new CornerRadius(16), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Top, Child = PreviewText };
        var gradient = new LinearGradientBrush { StartPoint = new Windows.Foundation.Point(0, 0), EndPoint = new Windows.Foundation.Point(1, 1) };
        gradient.GradientStops.Add(new GradientStop { Color = Color.FromArgb(255, 34, 48, 75), Offset = 0 });
        gradient.GradientStops.Add(new GradientStop { Color = Color.FromArgb(255, 181, 211, 220), Offset = 1 });
        preview.Children.Add(new Border { Height = 170, CornerRadius = new CornerRadius(8), Padding = new Thickness(12), Background = gradient, Child = PreviewPill }); AppearancePage.Children.Add(Card(preview));
        var dimensions = Panel(); dimensions.Children.Add(Heading("Dimensions"));
        WidthLabel = Label("Notch width"); HeightLabel = Label("Resting height"); RadiusLabel = Label("Corner radius");
        WidthSlider = MakeSlider(200, 520, 1, "Notch width"); HeightSlider = MakeSlider(28, 64, 1, "Notch height"); RadiusSlider = MakeSlider(0, 32, 1, "Corner radius");
        dimensions.Children.Add(WidthLabel); dimensions.Children.Add(WidthSlider); dimensions.Children.Add(HeightLabel); dimensions.Children.Add(HeightSlider); dimensions.Children.Add(RadiusLabel); dimensions.Children.Add(RadiusSlider); AppearancePage.Children.Add(Card(dimensions));
        var colors = Panel(); colors.Children.Add(Heading("Color & opacity")); OpacityLabel = Label("Background opacity"); OpacitySlider = MakeSlider(20, 100, 1, "Background opacity percent");
        BackgroundPicker = new ColorPicker { IsAlphaEnabled = false, IsAlphaSliderVisible = false };
        colors.Children.Add(OpacityLabel); colors.Children.Add(OpacitySlider); colors.Children.Add(new Expander { Header = "Choose a background color", Content = BackgroundPicker }); AppearancePage.Children.Add(Card(colors));
        var reset = new Button { Content = "Restore defaults", HorizontalAlignment = HorizontalAlignment.Left }; reset.Click += OnRestoreDefaults; AppearancePage.Children.Add(reset);
        var widgets = Panel(14); widgets.Children.Add(Heading("Choose your widgets")); widgets.Children.Add(Label("Enable the information shown inside the notch."));
        ClockToggle = new ToggleSwitch { Header = "Clock and date" }; BatteryToggle = new ToggleSwitch { Header = "Battery and charging" }; MediaToggle = new ToggleSwitch { Header = "Media controls" };
        widgets.Children.Add(ClockToggle); widgets.Children.Add(BatteryToggle); widgets.Children.Add(MediaToggle); WidgetsPage.Children.Add(Card(widgets));
        var behavior = Panel(); behavior.Children.Add(Heading("Opening the notch")); behavior.Children.Add(Label("Hover briefly to open the notch; it closes shortly after you leave. Clicking the header toggles it immediately.")); HoverToggle = new ToggleSwitch { Header = "Open on hover" }; behavior.Children.Add(HoverToggle); BehaviorPage.Children.Add(Card(behavior));
        var animations = Panel(); animations.Children.Add(Heading("Transition speed")); animations.Children.Add(Label("Choose how long the notch takes to open and close. Set to zero to disable motion.")); DurationLabel = Label("Duration"); DurationSlider = MakeSlider(0, 600, 20, "Animation duration in milliseconds"); animations.Children.Add(DurationLabel); animations.Children.Add(DurationSlider); AnimationsPage.Children.Add(Card(animations));
        var about = Panel(); about.Children.Add(new Image { Source = new BitmapImage(new Uri("ms-appx:///Assets/Square150x150Logo.png")), Width = 72, Height = 72, HorizontalAlignment = HorizontalAlignment.Left }); about.Children.Add(Heading("NotchUI")); about.Children.Add(Label("A compact Windows desktop notch for time, battery and media.")); about.Children.Add(Label("Closing settings keeps NotchUI running. Use the system tray icon to reopen settings or exit.")); AboutPage.Children.Add(Card(about));
        root.Children.Add(AppearancePage); root.Children.Add(WidgetsPage); root.Children.Add(BehaviorPage); root.Children.Add(AnimationsPage); root.Children.Add(AboutPage);
        nav.Content = new ScrollViewer { Content = root, VerticalScrollBarVisibility = ScrollBarVisibility.Auto };
        nav.SelectionChanged += OnNavigationChanged; nav.SelectedItem = appearanceItem;
        WidthSlider.ValueChanged += OnSliderChanged; HeightSlider.ValueChanged += OnSliderChanged; RadiusSlider.ValueChanged += OnSliderChanged; OpacitySlider.ValueChanged += OnSliderChanged;
        DurationSlider.ValueChanged += OnDurationChanged; BackgroundPicker.ColorChanged += OnColorChanged;
        ClockToggle.Toggled += OnModulesChanged; BatteryToggle.Toggled += OnModulesChanged; MediaToggle.Toggled += OnModulesChanged; HoverToggle.Toggled += OnHoverChanged;
        Content = nav;
    }
}
