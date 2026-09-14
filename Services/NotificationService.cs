using BradialWebhook.Configuration;
using Microsoft.Extensions.Options;

namespace BradialWebhook.Services;

public class NotificationService
{
    private readonly HttpClient _http;
    private readonly TelegramOptions _options;

    public NotificationService(
        HttpClient http,
        IOptions<TelegramOptions> options)
    {
        _http = http;
        _options = options.Value;
    }

    public async Task NotificarTelegram(
        string cliente,
        string telefone,
        CancellationToken cancellationToken)
    {
        cliente = NormalizarCampo(cliente, 200);
        telefone = NormalizarCampo(telefone, 50);

        var mensagem = $"""
🔔 Novo atendimento URGENTE

👤 Cliente: {cliente}

📱 Telefone: {telefone}
""";

        var dados = new Dictionary<string, string>
        {
            ["chat_id"] = _options.ChatId.ToString(),
            ["text"] = mensagem
        };

        using var response = await _http.PostAsync(
            $"./bot{_options.Token}/sendMessage",
            new FormUrlEncodedContent(dados),
            cancellationToken);

        if (!response.IsSuccessStatusCode)
            throw new HttpRequestException(
                $"O Telegram recusou a notificação com status {(int)response.StatusCode}.");
    }

    private static string NormalizarCampo(string valor, int tamanhoMaximo)
    {
        var caracteres = valor
            .Where(c => !char.IsControl(c) || c == ' ')
            .Take(tamanhoMaximo)
            .ToArray();

        var resultado = new string(caracteres).Trim();
        return string.IsNullOrEmpty(resultado) ? "Não informado" : resultado;
    }
}
