using CommunityToolkit.Mvvm.Messaging;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using NotchWindows.App.Services;
using NotchWindows.App.Views;
using NotchWindows.Core.Abstractions;
using NotchWindows.Core.Navigation;
using NotchWindows.Core.ViewModels;
using NotchWindows.Data;
using NotchWindows.Data.Repositories;
using NotchWindows.Services.Dock;
using NotchWindows.Services.Music;
using NotchWindows.Services.Network;
using NotchWindows.Services.Settings;
using NotchWindows.Services.System;
using NotchWindows.Services.Window;

namespace NotchWindows.App;

// QA fix (bug QA-015, P0 BLOCKER): composition root sebelumnya kosong total (hanya TODO + satu
// ServiceCollection tanpa registrasi) -> app tidak melakukan apa-apa saat dijalankan, tidak ada
// window yang muncul. Sekarang: single-instance guard, DI lengkap sesuai docs/02-architecture.md §1-2,
// migrasi DB saat startup, dan membuat+Activate() NotchShellWindow + DockBarWindow.
// Global shortcut belum didaftarkan otomatis. F-006 perlu menghormati preferensi pengguna sebelum
// implementasi hotkey diaktifkan; pengaturan baru tidak boleh menyalakan shortcut tanpa opt-in.
public partial class App : Application
{
    private const string SingleInstanceMutexName = "Local\\NotchWindows.SingleInstance";

    public static IServiceProvider Services { get; private set; } = null!;

    private System.Threading.Mutex? _singleInstanceMutex;
    private NotchShellWindow? _notchShellWindow;
    private DockBarWindow? _dockBarWindow;

    public App()
    {
        InitializeComponent();
    }

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        // Single-instance guard sederhana: instance kedua keluar diam-diam (notch sudah berjalan).
        _singleInstanceMutex = new System.Threading.Mutex(initiallyOwned: true, SingleInstanceMutexName, out var createdNew);
        if (!createdNew)
        {
            Environment.Exit(0);
            return;
        }

        var services = new ServiceCollection();
        AddInfrastructure(services);
        AddCoreServices(services);
        AddViewModels(services);
        Services = services.BuildServiceProvider();

        // Migrasi DB saat startup (lihat docs/05-database.md). Todo/Notes sendiri Rilis 2 (QA-014),
        // tapi menjalankan migrasi dari awal membuat file+skema siap dipakai begitu UI-nya ada.
        try
        {
            var connectionFactory = Services.GetRequiredService<SqliteConnectionFactory>();
            await connectionFactory.MigrateAsync();
        }
        catch (Exception ex)
        {
            // Storage is optional for the notch; preserve the existing database on failure.
            System.Diagnostics.Trace.TraceError("Database initialization failed: {0}", ex);
        }

        var settingsStore = Services.GetRequiredService<ISettingsStore>();
        await settingsStore.LoadAsync();

        _notchShellWindow = Services.GetRequiredService<NotchShellWindow>();
        _notchShellWindow.Activate();
        try
        {
            _dockBarWindow = Services.GetRequiredService<DockBarWindow>();
            _dockBarWindow.Activate();
        }
        catch (Exception ex) { System.Diagnostics.Trace.TraceError("Dock initialization failed: {0}", ex); }

        try { await _notchShellWindow.ViewModel.InitializeAsync(); }
        catch (Exception ex) { System.Diagnostics.Trace.TraceError("Notch services initialization failed: {0}", ex); }
        try { await Services.GetRequiredService<DashboardViewModel>().InitializeAsync(); }
        catch (Exception ex) { System.Diagnostics.Trace.TraceError("Dashboard initialization failed: {0}", ex); }
        // DockBarWindow sudah memanggil ViewModel.Initialize() di konstruktornya sendiri — tidak
        // dipanggil ulang di sini supaya tidak double-subscribe ke IDockService.Items (lihat DockBarWindow.xaml.cs).

    }

    /// <summary>Services/Data infrastructure: sensor, media, network, storage — lihat 02-architecture.md §1.</summary>
    private static void AddInfrastructure(IServiceCollection services)
    {
        services.AddSingleton<SqliteConnectionFactory>();
        services.AddSingleton<NotchDbContext>();
        services.AddSingleton<ITodoRepository, TodoRepository>();

        // Security fix (SEC-001, Low, docs/07-security.md): default HttpClient.Timeout (100s) terlalu
        // lama untuk panggilan yang memblokir render Dashboard (WeatherService) -- batasi eksplisit.
        services.AddSingleton(_ => new HttpClient { Timeout = TimeSpan.FromSeconds(10) });
        services.AddSingleton<BatteryService>();
        services.AddSingleton<ISettingsStore, JsonSettingsStore>();
        services.AddSingleton<ISystemStatsService, SystemStatsService>();
        services.AddSingleton<IMusicService, SmtcMusicService>();
        // CATATAN (temuan baru di luar cakupan QA-014..019, ditambahkan sebagai QA-021/QA-022 di
        // 06-qa-report.md): NetworkToggleService dan WeatherService TIDAK cocok dengan kontrak
        // INetworkService/IWeatherService (nama method/tipe balik beda) — pola yang sama dengan bug
        // QA-010/QA-011/QA-014 yang sudah diperbaiki. Registrasi di bawah ini akan GAGAL KOMPILASI
        // sampai salah satu sisi (interface atau implementasi) disamakan oleh Tech Lead/Architect.
        services.AddSingleton<INetworkService, NetworkToggleService>();
        services.AddSingleton<IWeatherService, WeatherService>();
        services.AddSingleton<IQuickToggleService, QuickToggleService>();
        services.AddSingleton<IDockService, RunningAppsService>();
        services.AddSingleton<FullscreenDetectionService>();
        services.AddSingleton<INotchPositionService, NotchInteropService>();
    }

    private static void AddCoreServices(IServiceCollection services)
    {
        services.AddSingleton<IMessenger>(WeakReferenceMessenger.Default);
        // CATATAN: registrasi di sini saja cukup untuk kompilasi/DI, tapi NotchNavigationService.ShowPanel()
        // belum benar-benar menukar Content ActivePanelHost di NotchShellWindow.xaml (event tidak
        // di-subscribe di mana pun) — gap terpisah di luar cakupan QA-014..019, dicatat di laporan QA
        // sebagai temuan baru untuk Designer/App.
        services.AddSingleton<INotchNavigationService, NotchNavigationService>();
    }

    private static void AddViewModels(IServiceCollection services)
    {
        services.AddSingleton<NotchShellViewModel>();
        services.AddSingleton<DashboardViewModel>();
        services.AddSingleton<MusicViewModel>();
        services.AddSingleton<DockBarViewModel>();
        services.AddTransient<SettingsViewModel>(); // dibuka on-demand, bukan singleton (F-050)

        services.AddSingleton<NotchShellWindow>();
        services.AddSingleton<DockBarWindow>();
        services.AddTransient<SettingsWindow>();
    }
}
