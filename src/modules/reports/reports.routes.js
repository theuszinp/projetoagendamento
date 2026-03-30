const express = require('express');
const { asyncHandler } = require('../../shared/http/async-handler');
const { authenticate, authorizeRoles } = require('../../shared/middleware/auth');
const { ROLES } = require('../../shared/constants/roles');
const reportsController = require('./reports.controller');

const router = express.Router();

router.get(
    '/tech-summary',
    authenticate,
    authorizeRoles(ROLES.ADMIN),
    asyncHandler(reportsController.techSummary)
);

module.exports = router;
