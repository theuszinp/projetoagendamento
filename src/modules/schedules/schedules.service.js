const { AppError } = require('../../shared/errors/app-error');
const { ROLES } = require('../../shared/constants/roles');
const {
    TICKET_STATUS,
    TECH_STATUS,
    NOTE_TYPE,
} = require('../../shared/constants/ticket-status');
const {
    normalizeIdentifier,
    isValidIdentifier,
} = require('../../shared/utils/identifier');
const schedulesRepository = require('./schedules.repository');

function parsePositiveInteger(value, fieldName) {
    const parsedValue = Number(value);

    if (!Number.isInteger(parsedValue) || parsedValue <= 0) {
        throw new AppError(`${fieldName} inválido.`, 400);
    }

    return parsedValue;
}

function assertCanAccessTicket(ticket, requester) {
    if (requester.role === ROLES.ADMIN) {
        return;
    }

    if (requester.role === ROLES.SELLER && Number(ticket.requested_by) === Number(requester.id)) {
        return;
    }

    if (requester.role === ROLES.TECH && Number(ticket.assigned_to) === Number(requester.id)) {
        return;
    }

    throw new AppError('Acesso negado a este agendamento.', 403);
}

function resolveNoteType(requesterRole, requestedType) {
    if (requesterRole === ROLES.ADMIN) {
        const resolvedType = requestedType || NOTE_TYPE.INTERNAL;
        if (![NOTE_TYPE.INTERNAL, NOTE_TYPE.TECHNICAL, NOTE_TYPE.SELLER].includes(resolvedType)) {
            throw new AppError('Tipo de observação inválido.', 400);
        }

        return resolvedType;
    }

    if (requesterRole === ROLES.SELLER) {
        return NOTE_TYPE.SELLER;
    }

    if (requesterRole === ROLES.TECH) {
        return NOTE_TYPE.TECHNICAL;
    }

    throw new AppError('Perfil sem permissão para registrar observações.', 403);
}

async function createSchedule({ requester, body }) {
    if (requester.role !== ROLES.SELLER) {
        throw new AppError('Apenas vendedores podem criar tickets.', 403);
    }

    const {
        title,
        description,
        priority,
        requestedBy,
        clientId,
        customerName,
        address,
        identifier,
        phoneNumber,
    } = body;

    const requestedById = parsePositiveInteger(requestedBy, 'requestedBy');
    if (Number(requester.id) !== requestedById) {
        throw new AppError('Tentativa de criar ticket para outro usuário.', 403);
    }

    if (!title || !description || !priority || !customerName) {
        throw new AppError(
            'Campos essenciais (título, descrição, prioridade, solicitante e nome) são obrigatórios.',
            400
        );
    }

    if (!clientId && (!address || !phoneNumber || !identifier)) {
        throw new AppError(
            'Para novo cliente, endereço, telefone e CPF/CNPJ são obrigatórios.',
            400
        );
    }

    if (clientId && (!address || !phoneNumber)) {
        throw new AppError(
            'O endereço e o telefone do cliente são obrigatórios, mesmo para clientes existentes.',
            400
        );
    }

    const normalizedIdentifier = normalizeIdentifier(identifier);
    if (!clientId && !isValidIdentifier(normalizedIdentifier)) {
        throw new AppError('O CPF/CNPJ informado é inválido.', 400);
    }

    if (clientId && identifier && !isValidIdentifier(normalizedIdentifier)) {
        throw new AppError('O CPF/CNPJ informado é inválido.', 400);
    }

    return schedulesRepository.withTransaction(async (db) => {
        let finalCustomerId = clientId ? parsePositiveInteger(clientId, 'clientId') : null;

        if (!finalCustomerId) {
            const existingCustomer = await schedulesRepository.findCustomerByNormalizedIdentifier(
                db,
                normalizedIdentifier
            );

            if (existingCustomer) {
                throw new AppError(`O identificador ${identifier} já está cadastrado em nossa base.`, 409);
            }

            const createdCustomer = await schedulesRepository.createCustomer(db, {
                name: customerName,
                address,
                identifier: normalizedIdentifier,
                phoneNumber,
            });

            finalCustomerId = createdCustomer.id;
        } else {
            const existingCustomer = await schedulesRepository.findCustomerById(db, finalCustomerId);
            if (!existingCustomer) {
                throw new AppError('Cliente existente não encontrado com o ID fornecido.', 404);
            }

            if (identifier) {
                const storedIdentifier = normalizeIdentifier(existingCustomer.identifier || '');
                if (storedIdentifier && storedIdentifier !== normalizedIdentifier) {
                    throw new AppError(
                        'O CPF/CNPJ informado não corresponde ao cliente existente.',
                        409
                    );
                }
            }

            await schedulesRepository.updateCustomer(db, {
                customerId: finalCustomerId,
                name: customerName,
                address,
                phoneNumber,
            });
        }

        const ticket = await schedulesRepository.createTicket(db, {
            title,
            description,
            priority,
            customerId: finalCustomerId,
            customerName,
            address,
            requestedBy: requestedById,
        });

        await schedulesRepository.insertStatusHistory(db, {
            ticketId: ticket.id,
            previousStatus: null,
            nextStatus: TICKET_STATUS.PENDING,
            actorId: requester.id,
            actorRole: requester.role,
            note: 'Solicitação criada pelo vendedor.',
        });

        return ticket;
    });
}

async function listAllSchedules() {
    return schedulesRepository.listAllTickets();
}

async function listSchedulesByRequester({ requester, requestedById }) {
    const parsedRequestedById = parsePositiveInteger(requestedById, 'requested_by_id');

    if (requester.role !== ROLES.ADMIN && Number(requester.id) !== parsedRequestedById) {
        throw new AppError('Acesso negado. Você só pode ver seus próprios tickets.', 403);
    }

    return schedulesRepository.listTicketsByRequester(parsedRequestedById);
}

async function listSchedulesByTechnician({ requester, technicianId }) {
    const parsedTechnicianId = parsePositiveInteger(technicianId, 'tech_id');

    if (requester.role !== ROLES.ADMIN && Number(requester.id) !== parsedTechnicianId) {
        throw new AppError('Acesso negado. Você só pode ver tickets atribuídos a você.', 403);
    }

    return schedulesRepository.listTicketsByTechnician(parsedTechnicianId);
}

async function getScheduleById({ requester, ticketId }) {
    const parsedTicketId = parsePositiveInteger(ticketId, 'ticketId');
    const ticket = await schedulesRepository.findTicketById(parsedTicketId);

    if (!ticket) {
        throw new AppError('Ticket não encontrado.', 404);
    }

    assertCanAccessTicket(ticket, requester);
    return ticket;
}

async function approveSchedule({ requester, ticketId, assignedTo }) {
    if (requester.role !== ROLES.ADMIN) {
        throw new AppError('Apenas administradores podem aprovar tickets.', 403);
    }

    const parsedTicketId = parsePositiveInteger(ticketId, 'ticketId');
    const technicianId = parsePositiveInteger(assignedTo, 'assigned_to');

    return schedulesRepository.withTransaction(async (db) => {
        const technician = await schedulesRepository.findTechnicianById(db, technicianId);
        if (!technician) {
            throw new AppError(
                `Técnico com ID ${technicianId} não encontrado ou não tem o cargo 'tech'.`,
                404
            );
        }

        const currentTicket = await schedulesRepository.lockTicketById(db, parsedTicketId);
        if (!currentTicket) {
            throw new AppError('Ticket não encontrado.', 404);
        }

        const ticket = await schedulesRepository.approveTicket(db, {
            ticketId: parsedTicketId,
            adminId: requester.id,
            technicianId,
        });

        await schedulesRepository.insertStatusHistory(db, {
            ticketId: parsedTicketId,
            previousStatus: currentTicket.status,
            nextStatus: TICKET_STATUS.APPROVED,
            actorId: requester.id,
            actorRole: requester.role,
            note: `Ticket atribuído ao técnico ${technician.name}.`,
        });

        return {
            ticket,
            notification_sent: false,
        };
    });
}

async function rejectSchedule({ requester, ticketId }) {
    if (requester.role !== ROLES.ADMIN) {
        throw new AppError('Apenas administradores podem reprovar tickets.', 403);
    }

    const parsedTicketId = parsePositiveInteger(ticketId, 'ticketId');

    return schedulesRepository.withTransaction(async (db) => {
        const currentTicket = await schedulesRepository.lockTicketById(db, parsedTicketId);
        if (!currentTicket) {
            throw new AppError('Ticket não encontrado para ser reprovado.', 404);
        }

        const ticket = await schedulesRepository.rejectTicket(db, {
            ticketId: parsedTicketId,
            adminId: requester.id,
        });

        await schedulesRepository.insertStatusHistory(db, {
            ticketId: parsedTicketId,
            previousStatus: currentTicket.status,
            nextStatus: TICKET_STATUS.REJECTED,
            actorId: requester.id,
            actorRole: requester.role,
            note: 'Ticket reprovado pelo administrador.',
        });

        return ticket;
    });
}

async function updateTechnicalStatus({ requester, ticketId, newStatus }) {
    if (requester.role !== ROLES.TECH) {
        throw new AppError('Apenas técnicos podem atualizar o status de trabalho do ticket.', 403);
    }

    const parsedTicketId = parsePositiveInteger(ticketId, 'ticketId');
    if (![TECH_STATUS.IN_PROGRESS, TECH_STATUS.COMPLETED].includes(newStatus)) {
        throw new AppError(
            `O status fornecido "${newStatus}" é inválido. Status permitidos: IN_PROGRESS, COMPLETED.`,
            400
        );
    }

    return schedulesRepository.withTransaction(async (db) => {
        const currentTicket = await schedulesRepository.lockTicketById(db, parsedTicketId);
        if (!currentTicket) {
            throw new AppError('Ticket não encontrado.', 404);
        }

        if (Number(currentTicket.assigned_to) !== Number(requester.id)) {
            throw new AppError('Ticket não atribuído a você.', 403);
        }

        if (currentTicket.status !== TICKET_STATUS.APPROVED) {
            throw new AppError('O ticket precisa estar aprovado pelo admin.', 403);
        }

        const currentTechStatus = currentTicket.tech_status;
        if (newStatus === TECH_STATUS.IN_PROGRESS && currentTechStatus) {
            throw new AppError('Este atendimento já foi iniciado.', 409);
        }

        if (newStatus === TECH_STATUS.COMPLETED && currentTechStatus !== TECH_STATUS.IN_PROGRESS) {
            throw new AppError('Só é possível concluir um atendimento já iniciado.', 409);
        }

        const updatedTicket = await schedulesRepository.updateTechStatus(db, {
            ticketId: parsedTicketId,
            userId: requester.id,
            newStatus,
        });

        await schedulesRepository.insertStatusHistory(db, {
            ticketId: parsedTicketId,
            previousStatus: currentTechStatus || currentTicket.status,
            nextStatus: newStatus,
            actorId: requester.id,
            actorRole: requester.role,
            note: `Status técnico atualizado para ${newStatus}.`,
        });

        return updatedTicket;
    });
}

async function listScheduleHistory({ requester, ticketId }) {
    const ticket = await getScheduleById({ requester, ticketId });
    const history = await schedulesRepository.listStatusHistory(ticket.id);
    const notes = await schedulesRepository.listTicketNotes(ticket.id);

    return {
        ticket,
        history,
        notes,
    };
}

async function addScheduleNote({ requester, ticketId, noteType, content }) {
    const parsedTicketId = parsePositiveInteger(ticketId, 'ticketId');

    if (!content || content.trim().length < 3) {
        throw new AppError('O conteúdo da observação é obrigatório.', 400);
    }

    const ticket = await schedulesRepository.findTicketById(parsedTicketId);
    if (!ticket) {
        throw new AppError('Ticket não encontrado.', 404);
    }

    assertCanAccessTicket(ticket, requester);

    return schedulesRepository.withTransaction(async (db) => {
        const resolvedNoteType = resolveNoteType(requester.role, noteType);
        const note = await schedulesRepository.insertTicketNote(db, {
            ticketId: parsedTicketId,
            authorId: requester.id,
            authorRole: requester.role,
            noteType: resolvedNoteType,
            content: content.trim(),
        });

        await schedulesRepository.insertStatusHistory(db, {
            ticketId: parsedTicketId,
            previousStatus: null,
            nextStatus: `NOTE:${resolvedNoteType.toUpperCase()}`,
            actorId: requester.id,
            actorRole: requester.role,
            note: content.trim(),
        });

        return note;
    });
}

async function listScheduleNotes({ requester, ticketId }) {
    const ticket = await getScheduleById({ requester, ticketId });
    const notes = await schedulesRepository.listTicketNotes(ticket.id);
    return {
        ticket,
        notes,
    };
}

module.exports = {
    createSchedule,
    listAllSchedules,
    listSchedulesByRequester,
    listSchedulesByTechnician,
    getScheduleById,
    approveSchedule,
    rejectSchedule,
    updateTechnicalStatus,
    listScheduleHistory,
    addScheduleNote,
    listScheduleNotes,
};
