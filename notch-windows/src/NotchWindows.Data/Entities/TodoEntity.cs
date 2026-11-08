namespace NotchWindows.Data.Entities;

/// <summary>
/// F-080 — Todo. Due time bahasa natural diparse di Core/Services sebelum disimpan sebagai DateTimeOffset.
/// QA fix (bug QA-014, P0): entity jadi POCO polos (bukan sqlite-net-pcl) — kolom dipetakan manual lewat
/// SQL di <see cref="NotchWindows.Data.Repositories.TodoRepository"/> (Dapper), bukan atribut [PrimaryKey]/[AutoIncrement].
/// </summary>
public sealed class TodoEntity
{
    public int Id { get; set; }
    public string Title { get; set; } = string.Empty;
    public DateTimeOffset? DueAt { get; set; }
    public bool IsCompleted { get; set; }
    public bool IsRecurring { get; set; }
    public string? RecurrenceRule { get; set; }
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.Now;
}
