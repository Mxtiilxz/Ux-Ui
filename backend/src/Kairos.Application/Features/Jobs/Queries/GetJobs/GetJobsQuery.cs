using MediatR;

namespace Kairos.Application.Features.Jobs.Queries.GetJobs;

public record GetJobsQuery(
    string? Search       = null,
    string? Status       = "Open",
    int     Page         = 1,
    int     PageSize     = 20) : IRequest<GetJobsResult>;

public record JobDto(
    int      Id,
    string   Title,
    string   Description,
    string?  Location,
    string?  ImageUrl,
    string   Status,
    DateTime CreatedAt,
    DateTime? ExpiresAt,
    int      CompanyId,
    string   CompanyName,
    string?  CompanyAvatarUrl,
    IReadOnlyList<JobSkillDto> Skills);

public record JobSkillDto(int Id, string Name, string Category);

public record GetJobsResult(
    IReadOnlyList<JobDto> Items,
    int  TotalCount,
    bool HasNextPage);
