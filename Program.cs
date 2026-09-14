using BradialWebhook.Configuration;
using BradialWebhook.Services;

const long tamanhoMaximoWebhook = 64 * 1024;

var builder = WebApplication.CreateBuilder(args);

// O Event Log do Windows pode exigir privilégios administrativos. O console é
// suficiente para esta aplicação e evita que uma falha de log derrube o webhook.
builder.Logging.ClearProviders();
builder.Logging.AddConsole();

// A URL do Telegram contém o token do bot. Desabilitar os logs automáticos do
// HttpClient impede que esse segredo apareça no console.
builder.Logging.AddFilter("System.Net.Http.HttpClient", LogLevel.None);

builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxRequestBodySize = tamanhoMaximoWebhook;
});

builder.Services.AddControllers();
builder.Services.AddOpenApi();

builder.Services.AddWindowsService(options =>
{
    options.ServiceName = "Bradial Webhook";
});

builder.Services
    .AddOptions<TelegramOptions>()
    .BindConfiguration(TelegramOptions.SectionName)
    .Validate(options => !string.IsNullOrWhiteSpace(options.Token) && options.Token.Contains(':'),
        "Telegram:Token não foi configurado corretamente.")
    .Validate(options => options.ChatId != 0,
        "Telegram:ChatId não foi configurado corretamente.")
    .ValidateOnStart();

builder.Services
    .AddOptions<BradialOptions>()
    .BindConfiguration(BradialOptions.SectionName)
    .Validate(options => options.DepartamentoUrgenteId > 0,
        "Bradial:DepartamentoUrgenteId não foi configurado corretamente.")
    .Validate(options => options.WebhookSecret?.Length >= 32,
        "Bradial:WebhookSecret deve ter pelo menos 32 caracteres.")
    .ValidateOnStart();

builder.Services.AddHttpClient<NotificationService>(httpClient =>
{
    httpClient.BaseAddress = new Uri("https://api.telegram.org/");
    httpClient.Timeout = TimeSpan.FromSeconds(10);
});

builder.Services.AddScoped<BradialService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseAuthorization();
app.MapControllers();

app.Run();
