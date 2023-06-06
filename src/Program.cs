using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

var host = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults((_, builder) =>
    {

    })
    .ConfigureAppConfiguration((hostContext, config) =>
    {
        if (hostContext.HostingEnvironment.IsDevelopment())
        {
            config.AddJsonFile("local.settings.json");
        }
    })
    .ConfigureServices((ctx, serviceProvider) =>
    {

    })
    .ConfigureLogging((context, builder) =>
    {
        
    })
    .Build();

await host.RunAsync();
