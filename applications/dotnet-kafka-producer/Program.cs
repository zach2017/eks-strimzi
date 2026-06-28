using KafkaProducer.Services;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

var builder = WebApplicationBuilder.CreateBuilder(args);

// Add services
builder.Services.AddSingleton<KafkaProducerService>();
builder.Services.AddControllers();
builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure middleware
app.UseRouting();
app.MapHealthChecks("/health");

// Kafka producer endpoint
app.MapPost("/api/produce", async (HttpContext context, KafkaProducerService producer, ILogger<Program> logger) =>
{
    try
    {
        var topic = context.Request.Query["topic"].ToString() ?? "example-topic";
        var key = context.Request.Query["key"].ToString() ?? "default-key";
        
        using var reader = new StreamReader(context.Request.Body);
        var body = await reader.ReadToEndAsync();
        
        await producer.SendMessageAsync(topic, key, body);
        
        return Results.Ok(new { message = "Message produced successfully" });
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Error producing message");
        return Results.BadRequest(new { error = ex.Message });
    }
});

// Health endpoint
app.MapGet("/api/health", () => Results.Ok(new { status = "healthy" }));

app.Run();
