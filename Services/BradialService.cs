using System.Text.Json;
using BradialWebhook.Configuration;
using Microsoft.Extensions.Options;

namespace BradialWebhook.Services;

public class BradialService
{
    private readonly int _departamentoUrgenteId;
    private readonly NotificationService _notification;

    public BradialService(
        NotificationService notification,
        IOptions<BradialOptions> options)
    {
        _notification = notification;
        _departamentoUrgenteId = options.Value.DepartamentoUrgenteId;
    }

    public async Task<ResultadoProcessamento> Processar(
        string json,
        CancellationToken cancellationToken)
    {
        using var documento = JsonDocument.Parse(json);
        var root = documento.RootElement;

        if (!root.TryGetProperty("event", out var evento) ||
            evento.ValueKind != JsonValueKind.String)
            return ResultadoProcessamento.IgnoradoSemEvento;

        if (!string.Equals(evento.GetString(), "conversation_updated", StringComparison.OrdinalIgnoreCase))
            return ResultadoProcessamento.IgnoradoEventoDiferente;

        if (!FoiParaDepartamento(root, _departamentoUrgenteId))
            return ResultadoProcessamento.IgnoradoDepartamentoDiferente;

        var cliente = ObterTexto(root, "meta", "sender", "name") ?? "Não informado";
        var telefone = ObterTexto(root, "meta", "sender", "phone_number") ?? "Não informado";

        await _notification.NotificarTelegram(cliente, telefone, cancellationToken);

        return ResultadoProcessamento.Notificado;
    }

    private static bool FoiParaDepartamento(JsonElement root, int departamentoId)
    {
        if (!root.TryGetProperty("changed_attributes", out var changed) ||
            changed.ValueKind != JsonValueKind.Array)
            return false;

        foreach (var item in changed.EnumerateArray())
        {
            if (!item.TryGetProperty("team_id", out var team) ||
                !team.TryGetProperty("current_value", out var atual))
                continue;

            if (atual.ValueKind == JsonValueKind.Number && atual.TryGetInt32(out var idNumerico))
                return idNumerico == departamentoId;

            if (atual.ValueKind == JsonValueKind.String &&
                int.TryParse(atual.GetString(), out var idTexto))
                return idTexto == departamentoId;
        }

        return false;
    }

    private static string? ObterTexto(JsonElement elemento, params string[] caminho)
    {
        foreach (var propriedade in caminho)
        {
            if (elemento.ValueKind != JsonValueKind.Object ||
                !elemento.TryGetProperty(propriedade, out elemento))
                return null;
        }

        return elemento.ValueKind == JsonValueKind.String
            ? elemento.GetString()
            : elemento.ToString();
    }
}

public enum ResultadoProcessamento
{
    IgnoradoSemEvento,
    IgnoradoEventoDiferente,
    IgnoradoDepartamentoDiferente,
    Notificado
}
