using System.ComponentModel;
using System.Diagnostics.Metrics;
using System.Net;
using System.Web;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Frbar.AzureSqlDbFuncManagedIdentity.Functions
{
    public class AlterDatabaseFunction
    {
        private readonly ILogger _logger;
        private readonly IConfiguration _configuration;

        public AlterDatabaseFunction(ILoggerFactory loggerFactory, 
                                     IConfiguration configuration)
        {
            _logger = loggerFactory.CreateLogger<AlterDatabaseFunction>();
            _configuration = configuration;
        }

        [Function("AlterDatabaseFunction")]
        public HttpResponseData Run([HttpTrigger(AuthorizationLevel.Anonymous, "get")] HttpRequestData req)
        {
            try
            {
                var query = HttpUtility.ParseQueryString(req.Url.Query);
                var databaseName = query["databaseName"];
                var changeTrackingEnabled = query["changeTrackingEnabled"] == "true";

                var serverName = _configuration.GetValue<string>("ServerName");
                var managedIdentityClientId = _configuration.GetValue<string>("ManagedIdentityClientId");
                var connectionString = $"Server={serverName}; Authentication=Active Directory Managed Identity; User Id={managedIdentityClientId}; Database={databaseName}";

                _logger.LogInformation("connection string: " + connectionString);

                var sqlQuery = $"ALTER DATABASE [{databaseName}] SET CHANGE_TRACKING = ON (CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON)";
                if (!changeTrackingEnabled)
                {
                    sqlQuery = $"ALTER DATABASE [{databaseName}] SET CHANGE_TRACKING = OFF";
                }

                _logger.LogInformation("sqlQuery: " + sqlQuery);

                using var sqlConnection = new SqlConnection(connectionString);
                sqlConnection.Open();
                using var sqlCommand = new SqlCommand(sqlQuery, sqlConnection);
                var result = sqlCommand.ExecuteNonQuery();

                _logger.LogInformation("result: " + result);

                var response = req.CreateResponse(HttpStatusCode.OK);
                response.Headers.Add("Content-Type", "text/plain; charset=utf-8");
                response.WriteString("Result: " + result);

                return response;
            }
            catch (Exception ex)
            {
                _logger.LogError("exception: " + ex.Message);
                _logger.LogError(ex, "Something unexpected occured");
                throw;
            }

            return null;
        }
    }
}
