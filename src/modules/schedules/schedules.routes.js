const express = require('express');
const { asyncHandler } = require('../../shared/http/async-handler');
const { authenticate, authorizeRoles } = require('../../shared/middleware/auth');
const { ROLES } = require('../../shared/constants/roles');
const schedulesController = require('./schedules.controller');

const router = express.Router();

router.post('/', authenticate, asyncHandler(schedulesController.create));
router.get('/', authenticate, authorizeRoles(ROLES.ADMIN), asyncHandler(schedulesController.listAll));
router.get('/requested/:requested_by_id', authenticate, asyncHandler(schedulesController.listByRequester));
router.get('/assigned/:tech_id', authenticate, asyncHandler(schedulesController.listByTechnician));
router.get('/:id/history', authenticate, asyncHandler(schedulesController.history));
router.get('/:id/notes', authenticate, asyncHandler(schedulesController.listNotes));
router.post('/:id/notes', authenticate, asyncHandler(schedulesController.createNote));
router.get('/:id', authenticate, asyncHandler(schedulesController.getById));
router.put('/:id/approve', authenticate, authorizeRoles(ROLES.ADMIN), asyncHandler(schedulesController.approve));
router.put('/:id/reject', authenticate, authorizeRoles(ROLES.ADMIN), asyncHandler(schedulesController.reject));
router.put('/:id/tech-status', authenticate, asyncHandler(schedulesController.updateTechStatus));

module.exports = router;
