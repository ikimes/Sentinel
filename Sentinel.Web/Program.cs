using Sentinel.Web.Components;
using Sentinel.Web.Features.InternalActors;
using Sentinel.Web.Features.Matters;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

var apiBaseAddress = builder.Configuration["MatterWorkspace:ApiBaseAddress"] ?? "http://sentinel-api";

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();
builder.Services.AddSingleton<IInternalActorProvider, ConfigurationInternalActorProvider>();
builder.Services.AddTransient<InternalActorHeadersHandler>();
builder.Services.AddHttpClient<MatterWorkspaceClient>(client =>
{
    client.BaseAddress = new Uri(apiBaseAddress);
})
    .AddHttpMessageHandler<InternalActorHeadersHandler>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
}

app.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true);
app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();
app.MapDefaultEndpoints();

app.Run();
