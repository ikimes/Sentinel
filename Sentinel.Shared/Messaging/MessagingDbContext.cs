using MassTransit;
using Microsoft.EntityFrameworkCore;

namespace Sentinel.Shared.Messaging;

public sealed class MessagingDbContext(DbContextOptions<MessagingDbContext> options) : DbContext(options)
{
    public const string SchemaName = "masstransit";
    public const string ComplianceLedgerSchema = "compliance_ledger";

    public DbSet<OutboxDispatchRecord> DispatchRecords => Set<OutboxDispatchRecord>();
    public DbSet<ComplianceLedgerEvent> ComplianceLedgerEvents => Set<ComplianceLedgerEvent>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.HasDefaultSchema(SchemaName);
        modelBuilder.AddInboxStateEntity();
        modelBuilder.AddOutboxMessageEntity();
        modelBuilder.AddOutboxStateEntity();

        modelBuilder.Entity<OutboxDispatchRecord>(entity =>
        {
            entity.ToTable("dispatch_records");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.SendMode).HasMaxLength(32).IsRequired();
            entity.Property(x => x.Destination).HasMaxLength(256).IsRequired();
            entity.Property(x => x.CreatedAtUtc).IsRequired();
            entity.Property(x => x.ActorId).HasMaxLength(128).IsRequired(false);
            entity.Property(x => x.ActorType).HasMaxLength(64).IsRequired(false);
            entity.Property(x => x.ActorDisplayName).HasMaxLength(256).IsRequired(false);
            entity.HasIndex(x => x.RequestId);
            entity.HasIndex(x => x.CreatedAtUtc);
        });

        modelBuilder.Entity<ComplianceLedgerEvent>(entity =>
        {
            entity.ToTable("events", ComplianceLedgerSchema);
            entity.HasKey(x => x.Id);
            entity.Property(x => x.RequestId).IsRequired();
            entity.Property(x => x.MessageId).IsRequired();
            entity.Property(x => x.Source).IsRequired(false);
            entity.Property(x => x.ContentLength).IsRequired();
            entity.Property(x => x.Status).HasMaxLength(32).IsRequired();
            entity.Property(x => x.HandlerDurationMs).IsRequired();
            entity.Property(x => x.ProcessedAtUtc).IsRequired();
            entity.Property(x => x.ErrorCode).HasMaxLength(64).IsRequired(false);
            entity.Property(x => x.ErrorDetail).HasMaxLength(2048).IsRequired(false);
            entity.Property(x => x.TraceId).HasMaxLength(128).IsRequired(false);

            entity.HasIndex(x => x.MessageId).IsUnique();
            entity.HasIndex(x => x.RequestId);
            entity.HasIndex(x => x.ProcessedAtUtc);
        });
    }
}

public sealed class OutboxDispatchRecord
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public Guid RequestId { get; init; }
    public string SendMode { get; init; } = string.Empty;
    public string Destination { get; init; } = string.Empty;
    public DateTime CreatedAtUtc { get; init; } = DateTime.UtcNow;
    public string? ActorId { get; init; }
    public string? ActorType { get; init; }
    public string? ActorDisplayName { get; init; }
}

public sealed class ComplianceLedgerEvent
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public Guid RequestId { get; init; }
    public Guid MessageId { get; init; }
    public Guid? CorrelationId { get; init; }
    public string? Source { get; init; }
    public int ContentLength { get; init; }
    public string Status { get; init; } = string.Empty;
    public int HandlerDurationMs { get; init; }
    public DateTime ProcessedAtUtc { get; init; } = DateTime.UtcNow;
    public string? ErrorCode { get; init; }
    public string? ErrorDetail { get; init; }
    public string? TraceId { get; init; }
}
