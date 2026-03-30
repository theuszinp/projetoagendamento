const express = require('express');
const cors = require('cors');
const morgan = require('morgan');

const authRoutes = require('./modules/auth/auth.routes');
const usersRoutes = require('./modules/users/users.routes');
const customersRoutes = require('./modules/customers/customers.routes');
const schedulesRoutes = require('./modules/schedules/schedules.routes');
const reportsRoutes = require('./modules/reports/reports.routes');
const { errorHandler, notFoundHandler } = require('./shared/http/error-handler');

function createApp() {
    const app = express();

    app.use(cors({ origin: '*' }));
    app.use(express.json());
    app.use(morgan('combined'));

    app.get('/', (req, res) => {
        res.json({
            success: true,
            message: 'API de agendamento de instalação online.',
            version: '4.0-modular',
        });
    });

    app.use('/', authRoutes);
    app.use('/users', usersRoutes);
    app.use('/clients', customersRoutes);
    app.use('/tickets', schedulesRoutes);
    app.use('/ticket', schedulesRoutes);
    app.use('/schedules', schedulesRoutes);
    app.use('/reports', reportsRoutes);

    app.use(notFoundHandler);
    app.use(errorHandler);

    return app;
}

module.exports = { createApp };
