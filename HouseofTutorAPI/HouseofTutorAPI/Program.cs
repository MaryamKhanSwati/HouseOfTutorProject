using HouseofTutorAPI.Models;
using HouseofTutorAPI.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Server.Kestrel.Core;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

using System.Text;

public partial class Program
{
    private static void Main(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);

        // =====================================================
        // 1. JWT AUTHENTICATION
        // =====================================================

        var jwtSettings = builder.Configuration.GetSection("Jwt");

        builder.Services
            .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.RequireHttpsMetadata = false;
                options.SaveToken = true;

                options.TokenValidationParameters =
                    new TokenValidationParameters
                    {
                        ValidateIssuer = true,
                        ValidateAudience = true,
                        ValidateLifetime = true,
                        ValidateIssuerSigningKey = true,

                        ValidIssuer = jwtSettings["Issuer"],
                        ValidAudience = jwtSettings["Audience"],

                        IssuerSigningKey = new SymmetricSecurityKey(
                            Encoding.UTF8.GetBytes(
                                jwtSettings["Key"] ??
                                throw new InvalidOperationException(
                                    "JWT Key is missing."
                                )
                            )
                        )
                    };
            });

        // =====================================================
        // 2. FILE UPLOAD CONFIGURATION
        // Maximum upload size: 100 MB
        // =====================================================

        builder.Services.Configure<FormOptions>(options =>
        {
            options.MultipartBodyLengthLimit = 100 * 1024 * 1024;

            options.ValueLengthLimit = int.MaxValue;

            options.MultipartHeadersLengthLimit = int.MaxValue;
        });

        // =====================================================
        // 3. KESTREL SERVER CONFIGURATION
        // =====================================================

        builder.WebHost.ConfigureKestrel(options =>
        {
            options.Limits.MaxRequestBodySize =
                100 * 1024 * 1024;

            options.Limits.MinRequestBodyDataRate = null;

            options.Limits.MinResponseDataRate = null;
        });

        // Run backend on port 5058
        builder.WebHost.UseUrls("http://0.0.0.0:5058");

        // =====================================================
        // 4. CONTROLLERS
        // =====================================================

        builder.Services.AddControllers();

        // =====================================================
        // 5. SWAGGER
        // =====================================================

        builder.Services.AddEndpointsApiExplorer();

        builder.Services.AddSwaggerGen();

        // =====================================================
        // 6. SQL SERVER DATABASE
        // =====================================================

        builder.Services.AddDbContext<HouseofTutorDbContext>(
            options =>
            {
                options.UseSqlServer(
                    builder.Configuration.GetConnectionString("dbcs")
                );
            }
        );

        // =====================================================
        // 7. CORS
        // =====================================================

        builder.Services.AddCors(options =>
        {
            options.AddPolicy("AllowFlutter", policy =>
            {
                policy
                    .AllowAnyOrigin()
                    .AllowAnyMethod()
                    .AllowAnyHeader();
            });
        });

        // =====================================================
        // 8. SERVICES
        // =====================================================

        builder.Services.AddHttpClient<GeoService>();

    builder.Services.AddHostedService<TutorRequestQueueService>();

        // =====================================================
        // 9. BUILD APPLICATION
        // =====================================================

        var app = builder.Build();

        // =====================================================
        // 10. SWAGGER
        // =====================================================

        if (app.Environment.IsDevelopment())
        {
            app.UseSwagger();

            app.UseSwaggerUI();
        }

        // =====================================================
        // 11. MIDDLEWARE ORDER
        // =====================================================

        app.UseRouting();

        // CORS before authentication
        app.UseCors("AllowFlutter");

        // Serve uploaded images, PDFs and documents
        app.UseStaticFiles();

        // JWT authentication
        app.UseAuthentication();

        // Authorization
        app.UseAuthorization();

        // =====================================================
        // 12. MAP CONTROLLERS
        // =====================================================

        app.MapControllers();

        // =====================================================
        // 13. RUN BACKEND
        // =====================================================

        app.Run();
    }
}
