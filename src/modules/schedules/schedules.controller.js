const schedulesService = require('./schedules.service');

async function create(req, res) {
    const ticket = await schedulesService.createSchedule({
        requester: req.user,
        body: req.body,
    });

    res.status(201).json({
        success: true,
        ticket,
    });
}

async function listAll(req, res) {
    const tickets = await schedulesService.listAllSchedules();
    res.json({
        success: true,
        tickets,
    });
}

async function listByRequester(req, res) {
    const tickets = await schedulesService.listSchedulesByRequester({
        requester: req.user,
        requestedById: req.params.requested_by_id,
    });

    res.json({
        success: true,
        tickets,
    });
}

async function listByTechnician(req, res) {
    const tickets = await schedulesService.listSchedulesByTechnician({
        requester: req.user,
        technicianId: req.params.tech_id,
    });

    res.json({
        success: true,
        tickets,
    });
}

async function getById(req, res) {
    const ticket = await schedulesService.getScheduleById({
        requester: req.user,
        ticketId: req.params.id,
    });

    res.json({
        success: true,
        ticket,
    });
}

async function approve(req, res) {
    const result = await schedulesService.approveSchedule({
        requester: req.user,
        ticketId: req.params.id,
        assignedTo: req.body.assigned_to,
    });

    res.json({
        success: true,
        ticket: result.ticket,
        notification_sent: result.notification_sent,
    });
}

async function reject(req, res) {
    const ticket = await schedulesService.rejectSchedule({
        requester: req.user,
        ticketId: req.params.id,
    });

    res.json({
        success: true,
        message: `Ticket ID ${req.params.id} foi reprovado com sucesso e seu status foi atualizado para REJECTED.`,
        ticket,
    });
}

async function updateTechStatus(req, res) {
    const ticket = await schedulesService.updateTechnicalStatus({
        requester: req.user,
        ticketId: req.params.id,
        newStatus: req.body.new_status,
    });

    res.json({
        success: true,
        message: `Status de trabalho do ticket ${req.params.id} atualizado para ${req.body.new_status}.`,
        ticket,
    });
}

async function history(req, res) {
    const result = await schedulesService.listScheduleHistory({
        requester: req.user,
        ticketId: req.params.id,
    });

    res.json({
        success: true,
        ...result,
    });
}

async function listAttachments(req, res) {
    const result = await schedulesService.listScheduleAttachments({
        requester: req.user,
        ticketId: req.params.id,
    });

    res.json({
        success: true,
        ...result,
    });
}

async function listNotes(req, res) {
    const result = await schedulesService.listScheduleNotes({
        requester: req.user,
        ticketId: req.params.id,
    });

    res.json({
        success: true,
        ...result,
    });
}

async function createNote(req, res) {
    const note = await schedulesService.addScheduleNote({
        requester: req.user,
        ticketId: req.params.id,
        noteType: req.body.note_type,
        content: req.body.content,
    });

    res.status(201).json({
        success: true,
        note,
    });
}

async function createAttachment(req, res) {
    const attachment = await schedulesService.addScheduleAttachment({
        requester: req.user,
        ticketId: req.params.id,
        fileName: req.body.file_name,
        contentType: req.body.content_type,
        base64Content: req.body.base64_content,
    });

    res.status(201).json({
        success: true,
        attachment,
    });
}

module.exports = {
    create,
    listAll,
    listByRequester,
    listByTechnician,
    getById,
    approve,
    reject,
    updateTechStatus,
    history,
    listAttachments,
    listNotes,
    createAttachment,
    createNote,
};
