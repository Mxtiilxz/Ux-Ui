using System.Security.Claims;
using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Jobs.Commands.ApplyToJob;
using Kairos.Application.Features.Jobs.Commands.CreateJobPosting;
using Kairos.Application.Features.Jobs.Queries.GetJobs;
using Kairos.Domain.Entities;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Kairos.API.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class JobsController(IMediator mediator, IApplicationDbContext db) : ControllerBase
{
    private int GetUserId() => int.Parse(
        User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? User.FindFirstValue("sub")
        ?? throw new UnauthorizedAccessException());

    private string GetRole() =>
        User.FindFirstValue(ClaimTypes.Role) ?? "student";

    [HttpGet]
    public async Task<IActionResult> GetJobs(
        [FromQuery] string? search   = null,
        [FromQuery] string? status   = "Open",
        [FromQuery] int     page     = 1,
        [FromQuery] int     pageSize = 20,
        CancellationToken   ct       = default)
    {
        var result = await mediator.Send(new GetJobsQuery(search, status, page, pageSize), ct);
        return Ok(result);
    }

    [HttpPost]
    public async Task<IActionResult> CreateJobPosting(
        [FromBody] CreateJobRequest request,
        CancellationToken ct)
    {
        if (GetRole() != "company") return Forbid();

        var id = await mediator.Send(new CreateJobPostingCommand(
            GetUserId(), request.Title, request.Description,
            request.Location, request.ExpiresAt, request.ImageUrl,
            request.SkillIds), ct);

        return CreatedAtAction(nameof(GetJobs), new { id }, id);
    }

    /// <summary>Company's own postings with application counts.</summary>
    [HttpGet("my-postings")]
    public async Task<IActionResult> GetMyPostings(CancellationToken ct)
    {
        if (GetRole() != "company") return Forbid();

        var companyId = GetUserId();
        var postings = await db.JobPostings
            .Where(j => j.CompanyId == companyId)
            .OrderByDescending(j => j.CreatedAt)
            .Select(j => new
            {
                j.Id,
                j.Title,
                j.Description,
                j.Location,
                j.ImageUrl,
                Status = j.Status.ToString(),
                j.CreatedAt,
                j.ExpiresAt,
                ApplicationCount = j.Applications.Count,
            })
            .ToListAsync(ct);

        return Ok(postings);
    }

    /// <summary>List applicants for one of the company's job postings.</summary>
    [HttpGet("{jobId:int}/applications")]
    public async Task<IActionResult> GetApplications(int jobId, CancellationToken ct)
    {
        if (GetRole() != "company") return Forbid();

        var companyId = GetUserId();
        var posting = await db.JobPostings
            .Where(j => j.Id == jobId && j.CompanyId == companyId)
            .FirstOrDefaultAsync(ct);

        if (posting is null) return NotFound();

        var applications = await db.JobApplications
            .Where(a => a.JobId == jobId)
            .OrderByDescending(a => a.CreatedAt)
            .Select(a => new
            {
                a.Id,
                a.CreatedAt,
                a.CvUrl,
                Status = a.Status.ToString(),
                Applicant = new
                {
                    a.Applicant.Id,
                    a.Applicant.FullName,
                    a.Applicant.Email,
                    a.Applicant.Institution,
                    a.Applicant.ProfilePictureUrl,
                },
            })
            .ToListAsync(ct);

        return Ok(applications);
    }

    /// <summary>Update a job posting (company owner only).</summary>
    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateJobPosting(
        int id,
        [FromBody] CreateJobRequest request,
        CancellationToken ct)
    {
        if (GetRole() != "company") return Forbid();

        var posting = await db.JobPostings
            .FirstOrDefaultAsync(j => j.Id == id && j.CompanyId == GetUserId(), ct);

        if (posting is null) return NotFound();

        posting.Title       = request.Title;
        posting.Description = request.Description;
        posting.Location    = request.Location;
        if (request.ImageUrl  != null) posting.ImageUrl  = request.ImageUrl;
        if (request.ExpiresAt.HasValue) posting.ExpiresAt = request.ExpiresAt;

        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    /// <summary>Delete a job posting (company owner only).</summary>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteJobPosting(int id, CancellationToken ct)
    {
        if (GetRole() != "company") return Forbid();

        var posting = await db.JobPostings
            .FirstOrDefaultAsync(j => j.Id == id && j.CompanyId == GetUserId(), ct);

        if (posting is null) return NotFound();

        db.JobPostings.Remove(posting);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPost("{jobId:int}/apply")]
    public async Task<IActionResult> ApplyToJob(
        int jobId,
        [FromBody] ApplyRequest request,
        CancellationToken ct)
    {
        try
        {
            var applicationId = await mediator.Send(
                new ApplyToJobCommand(jobId, GetUserId(), request.CvUrl), ct);
            return CreatedAtAction(nameof(GetJobs), new { id = applicationId }, applicationId);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { detail = ex.Message });
        }
    }
}

public record CreateJobRequest(
    string    Title,
    string    Description,
    string?   Location  = null,
    string?   ImageUrl  = null,
    DateTime? ExpiresAt = null,
    IReadOnlyList<int>? SkillIds = null);

public record ApplyRequest(string? CvUrl = null);
