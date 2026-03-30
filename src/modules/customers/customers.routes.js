const express = require('express');
const { asyncHandler } = require('../../shared/http/async-handler');
const { authenticate, authorizeRoles } = require('../../shared/middleware/auth');
const { ROLES } = require('../../shared/constants/roles');
const customersController = require('./customers.controller');

const router = express.Router();

router.get(
    '/search',
    authenticate,
    authorizeRoles(ROLES.ADMIN, ROLES.SELLER),
    asyncHandler(customersController.search)
);

module.exports = router;
