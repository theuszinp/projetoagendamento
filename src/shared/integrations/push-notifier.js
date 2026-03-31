let firebaseAdmin = null;

try {
    firebaseAdmin = require('../../../firebase');
} catch (error) {
    console.warn('PushNotifier: Firebase Admin indisponível.', error.message);
}

async function sendPushNotification({
    deviceToken,
    title,
    body,
    data = {},
}) {
    if (!deviceToken || !firebaseAdmin) {
        return false;
    }

    if (!firebaseAdmin.apps || firebaseAdmin.apps.length === 0) {
        return false;
    }

    try {
        await firebaseAdmin.messaging().send({
            token: deviceToken,
            notification: {
                title,
                body,
            },
            data: Object.fromEntries(
                Object.entries(data).map(([key, value]) => [key, String(value)])
            ),
            android: {
                priority: 'high',
                notification: {
                    channelId: 'tracker_services',
                    clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                },
            },
        });

        return true;
    } catch (error) {
        console.error('PushNotifier: erro ao enviar push.', error.message);
        return false;
    }
}

module.exports = {
    sendPushNotification,
};
