using NotchWindows.Core.Models;

namespace NotchWindows.Core.Messaging;

// Pesan dikirim lewat CommunityToolkit.Mvvm.Messaging.WeakReferenceMessenger supaya
// NotchShellWindow dan DockBarWindow tidak saling reference langsung (lihat docs/02-architecture.md §2).

public sealed record TrackChangedMessage(TrackInfo Track);

public sealed record SystemStatusChangedMessage(SystemStatus Status);

public sealed record ThemeChangedMessage(AppTheme Theme);

public sealed record NotchExpandRequestedMessage(bool Expand);
