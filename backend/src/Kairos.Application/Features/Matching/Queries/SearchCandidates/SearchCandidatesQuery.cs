using MediatR;

namespace Kairos.Application.Features.Matching.Queries.SearchCandidates;

public record SearchCandidatesQuery(IReadOnlyList<int> SkillIds) : IRequest<IReadOnlyList<CandidateDto>>;

public record SkillDto(int Id, string Name, string Category);

public record CandidateDto(
    int      Id,
    string   FullName,
    string?  Institution,
    string?  ProfilePictureUrl,
    int      MatchCount,
    int      SearchedCount,
    int      MatchPercentage,
    IReadOnlyList<SkillDto> MatchedSkills,
    IReadOnlyList<SkillDto> MissingSkills);
