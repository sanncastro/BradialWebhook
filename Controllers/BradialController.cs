using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using BradialWebhook.Configuration;
using BradialWebhook.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace BradialWebhook.Controllers;

[ApiController]
[Route("api/webhook/bradial")]
public class BradialController : ControllerBase
{
    private const long TamanhoMaximoWebhook = 64 * 1024;

    private readonly BradialService _bradial;
    private readonly BradialOptions _options;
    private readonly ILogger<BradialController> _logger;

    public BradialController(
        BradialService bradial,
        IOptions<BradialOptions> options,
        ILogger<BradialController> logger)
    {
        _bradial = bradial;
        _options = options.Value;
        _logger = logger;
    }

    [HttpPost]
    [RequestSizeLimit(TamanhoMaximoWebhook)]
    public async Task<IActionResult> Receber(CancellationToken cancellationToken)
    {
        if (!SegredoValido(Request.Query["secret"].ToString()))
        {
            _logger.LogWarning("Tentativa de acesso ao webhook com segredo ausente ou inválido");
            return Unauthorized();
        }

        if (!Request.HasJsonContentType())
            return StatusCode(StatusCodes.Status415UnsupportedMediaType);

        using var reader = new StreamReader(
            Request.Body,
            Encoding.UTF8,
            detectEncodingFromByteOrderMarks: false,
            bufferSize: 4096,
            leaveOpen: true);

        var json = await reader.ReadToEndAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(json))
        {
            _logger.LogWarning("Webhook recebido sem conteúdo");
            return BadRequest("O corpo do webhook está vazio.");
        }

        try
        {
            var resultado = await _bradial.Processar(json, cancellationToken);
            _logger.LogInformation("Webhook Bradial processado: {Resultado}", resultado);
            return Ok();
        }
        catch (JsonException)
        {
            _logger.LogWarning("Webhook recebido com JSON inválido");
            return BadRequest("O corpo do webhook não contém um JSON válido.");
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Não foi possível entregar a notificação ao Telegram");
            return StatusCode(StatusCodes.Status502BadGateway);
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogError("O Telegram não respondeu dentro do tempo limite");
            return StatusCode(StatusCodes.Status504GatewayTimeout);
        }
    }

    [HttpGet]
    public IActionResult Teste()
    {
        return Ok("Webhook Bradial funcionando!");
    }

    private bool SegredoValido(string segredoRecebido)
    {
        if (string.IsNullOrWhiteSpace(segredoRecebido))
            return false;

        var esperado = SHA256.HashData(Encoding.UTF8.GetBytes(_options.WebhookSecret));
        var recebido = SHA256.HashData(Encoding.UTF8.GetBytes(segredoRecebido));

        return CryptographicOperations.FixedTimeEquals(esperado, recebido);
    }
}
