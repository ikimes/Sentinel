using System.Text.Json.Serialization;

namespace Sentinel.Shared.Contracts;

public record AnalyzeComplianceRequest(
    Guid RequestId, 
    string Content, 
    string Source
);

[JsonSerializable(typeof(AnalyzeComplianceRequest))]
public partial class ComplianceJsonContext : JsonSerializerContext { }
