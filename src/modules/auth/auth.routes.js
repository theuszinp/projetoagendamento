const express = require('express');
const { asyncHandler } = require('../../shared/http/async-handler');
const authController = require('./auth.controller');

const router = express.Router();

router.post('/login', asyncHandler(authController.login));
router.post('/users', asyncHandler(authController.register));
router.put('/approve-user/:id', asyncHandler(authController.approveUser));
router.get('/pending-users', asyncHandler(authController.listPendingUsers));

module.exports = router;
