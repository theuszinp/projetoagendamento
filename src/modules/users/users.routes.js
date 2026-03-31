const express = require('express');
const { asyncHandler } = require('../../shared/http/async-handler');
const { authenticate, authorizeRoles } = require('../../shared/middleware/auth');
const { ROLES } = require('../../shared/constants/roles');
const usersController = require('./users.controller');

const router = express.Router();

router.put('/me/device-token', authenticate, asyncHandler(usersController.updateDeviceToken));
router.put('/:id/password', authenticate, asyncHandler(usersController.updatePassword));
router.get('/', authenticate, authorizeRoles(ROLES.ADMIN), asyncHandler(usersController.listUsers));
router.get(
    '/technicians',
    authenticate,
    authorizeRoles(ROLES.ADMIN, ROLES.SELLER),
    asyncHandler(usersController.listTechnicians)
);

module.exports = router;
