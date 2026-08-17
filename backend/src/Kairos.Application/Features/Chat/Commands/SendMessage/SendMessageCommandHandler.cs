using Kairos.Application.Common.Exceptions;
using Kairos.Application.Common.Interfaces;
using Kairos.Application.Features.Chat.Queries.GetMessages;
using Kairos.Domain.Entities;
using MediatR;

namespace Kairos.Application.Features.Chat.Commands.SendMessage;

public class SendMessageCommandHandler(IApplicationDbContext db, IAudienceService audience)
    : IRequestHandler<SendMessageCommand, MessageDto>
{
    public async Task<MessageDto> Handle(SendMessageCommand request, CancellationToken cancellationToken)
    {
        // La preferencia del destinatario manda. Se comprueba aquí y no en el
        // controlador porque el mismo comando lo usa el contacto de Quick Match.
        if (!await audience.CanSendMessageAsync(request.SenderId, request.ReceiverId, cancellationToken))
            throw new ForbiddenException(
                "Esta persona solo acepta mensajes de sus contactos.");

        var message = new Message
        {
            SenderId   = request.SenderId,
            ReceiverId = request.ReceiverId,
            Content    = request.Content,
        };

        db.Messages.Add(message);
        await db.SaveChangesAsync(cancellationToken);

        return new MessageDto(
            message.Id,
            message.SenderId,
            message.ReceiverId,
            message.Content,
            message.CreatedAt,
            message.IsRead);
    }
}
