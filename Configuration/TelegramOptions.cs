namespace BradialWebhook.Configuration;

public sealed class TelegramOptions
{
    public const string SectionName = "Telegram";

    public string Token { get; init; } = string.Empty;
    public long ChatId { get; init; }
}
