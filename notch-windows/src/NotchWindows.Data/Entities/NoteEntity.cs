namespace NotchWindows.Data.Entities;

/// <summary>
/// F-081 — Note, mendukung mode flashcard dari baris "pertanyaan :: jawaban".
/// QA fix (bug QA-014, P0): entity jadi POCO polos (bukan sqlite-net-pcl), dipetakan lewat Dapper.
/// </summary>
public sealed class NoteEntity
{
    public int Id { get; set; }
    public string Content { get; set; } = string.Empty;
    public bool IsFlashcardMode { get; set; }
    public DateTimeOffset UpdatedAt { get; set; } = DateTimeOffset.Now;
}
