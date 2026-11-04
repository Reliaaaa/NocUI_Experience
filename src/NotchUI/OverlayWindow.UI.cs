using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Automation;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Text;
using Windows.UI;

namespace NotchUI;

public sealed partial class OverlayWindow
{
    private Border Pill = null!;
    private TextBlock SummaryText = null!, ClockText = null!, CompactBatteryText = null!, DateText = null!, BatteryText = null!, MediaText = null!;
    private StackPanel ExpandedContent = null!, MediaControls = null!;
    private Button PreviousButton = null!, PlayPauseButton = null!, NextButton = null!;
    private FontIcon PlayPauseIcon = null!;

    private void InitializeComponent()
    {
        var white = new SolidColorBrush(Color.FromArgb(255, 255, 255, 255));
        TextBlock Label(bool strong = false) => new() { Foreground = white, FontWeight = strong ? FontWeights.SemiBold : FontWeights.Normal, VerticalAlignment = VerticalAlignment.Center, TextTrimming = TextTrimming.CharacterEllipsis };
        SummaryText = Label(true); ClockText = Label(true); CompactBatteryText = Label();
        ClockText.Margin = new Thickness(12, 0, 0, 0);
        CompactBatteryText.Margin = new Thickness(10, 0, 0, 0);
        var header = new Grid();
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        header.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        Grid.SetColumn(ClockText, 1); Grid.SetColumn(CompactBatteryText, 2);
        header.Children.Add(SummaryText); header.Children.Add(ClockText); header.Children.Add(CompactBatteryText);
        header.Tapped += OnHeaderTapped;
        DateText = Label(); DateText.Opacity = 0.75;
        BatteryText = Label(); BatteryText.Opacity = 0.75;
        MediaText = Label(true);
        PlayPauseIcon = new FontIcon { Glyph = "\uE768" };
        PreviousButton = new Button { Content = new FontIcon { Glyph = "\uE892" } };
        PlayPauseButton = new Button { Content = PlayPauseIcon };
        NextButton = new Button { Content = new FontIcon { Glyph = "\uE893" } };
        AutomationProperties.SetName(PreviousButton, "Previous track");
        AutomationProperties.SetName(PlayPauseButton, "Play or pause");
        AutomationProperties.SetName(NextButton, "Next track");
        PreviousButton.Click += OnPreviousClicked; PlayPauseButton.Click += OnPlayPauseClicked; NextButton.Click += OnNextClicked;
        MediaControls = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8 };
        MediaControls.Children.Add(PreviousButton); MediaControls.Children.Add(PlayPauseButton); MediaControls.Children.Add(NextButton);
        ExpandedContent = new StackPanel { Visibility = Visibility.Collapsed, Spacing = 4 };
        ExpandedContent.Children.Add(DateText); ExpandedContent.Children.Add(BatteryText); ExpandedContent.Children.Add(MediaText); ExpandedContent.Children.Add(MediaControls);
        var content = new StackPanel { Spacing = 8, Padding = new Thickness(16, 6, 16, 6) };
        content.Children.Add(header); content.Children.Add(ExpandedContent);
        Pill = new Border { Background = new SolidColorBrush(Color.FromArgb(255, 0, 0, 0)), HorizontalAlignment = HorizontalAlignment.Center, VerticalAlignment = VerticalAlignment.Top, Child = content };
        Pill.PointerEntered += OnPointerEntered; Pill.PointerExited += OnPointerExited;
        var root = new Grid { Background = new SolidColorBrush(Color.FromArgb(0, 0, 0, 0)) };
        root.Children.Add(Pill); Content = root;
    }
}
