namespace BradialWebhook.Configuration;

public sealed class BradialOptions
{
    public const string SectionName = "Bradial";

    public int DepartamentoUrgenteId { get; init; }
    public string WebhookSecret { get; init; } = string.Empty;
}
