const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendNotificationOnNewItem = functions.firestore
    .document('notifications/{userId}/items/{itemId}')
    .onCreate(async (snap, context) => {
        const notificationData = snap.data();
        const userId = context.params.userId;

        const type = notificationData.type || '';
        const fromUserName = notificationData.fromUserName || 'Biri';
        const text = notificationData.text || 'Yeni bir bildiriminiz var.';
        const fromUserId = notificationData.fromUserId || '';
        
        let title = 'Acil Durum Bildirimi';
        if (type === 'follow') title = 'Yeni Takip';
        else if (type === 'message') title = 'Yeni Mesaj';
        else if (type === 'like') title = 'Yeni Begeni';
        else if (type === 'team_sos') title = '🚨 EKIP SOS!';

        const userDoc = await admin.firestore().collection('users').doc(userId).get();
        if (!userDoc.exists) return null;

        const userData = userDoc.data();
        const fcmTokens = userData.fcmTokens || [];
        if (fcmTokens.length === 0) return null;

        const payload = {
            notification: {
                title: title,
                body: ${fromUserName} ,
            },
            data: {
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: type,
                fromUserId: fromUserId
            }
        };

        return admin.messaging().sendEachForMulticast({
            tokens: fcmTokens,
            notification: payload.notification,
            data: payload.data,
            android: {
                priority: 'high',
                notification: {
                    channelId: 'rota_plus_fcm_channel',
                    sound: 'default'
                }
            }
        });
    });

// 1. Yeni Takim Mesaji Bildirimi
exports.onNewTeamMessage = functions.firestore
    .document('teams/{teamId}/messages/{messageId}')
    .onCreate(async (snap, context) => {
        const messageData = snap.data();
        const teamId = context.params.teamId;
        const senderId = messageData.senderId;
        const senderName = messageData.senderName || 'Biri';
        let text = messageData.text || '';
        
        if (messageData.imageUrl) text = '📷 Bir fotograf gonderdi';
        else if (messageData.audioUrl) text = '🎵 Bir ses kaydi gonderdi';

        const teamDoc = await admin.firestore().collection('teams').doc(teamId).get();
        const teamName = teamDoc.exists ? (teamDoc.data().name || 'Takim') : 'Takim';

        const usersSnap = await admin.firestore().collection('users').where('team_id', '==', teamId).get();
        
        let tokens = [];
        usersSnap.forEach(doc => {
            if (doc.id !== senderId) {
                const data = doc.data();
                if (data.fcmTokens && data.fcmTokens.length > 0) {
                    tokens = tokens.concat(data.fcmTokens);
                }
            }
        });

        if (tokens.length === 0) return null;

        const payload = {
            notification: {
                title: ${teamName} - ,
                body: text,
            },
            data: {
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: 'team_message',
                teamId: teamId
            }
        };

        return admin.messaging().sendEachForMulticast({
            tokens: tokens,
            notification: payload.notification,
            data: payload.data,
            android: {
                priority: 'high',
                notification: {
                    channelId: 'rota_plus_fcm_channel',
                    sound: 'default'
                }
            }
        });
    });

// 2. SOS Bildirimi
exports.onSosAlert = functions.firestore
    .document('sos_alerts/{userId}')
    .onCreate(async (snap, context) => {
        const sosData = snap.data();
        const userId = context.params.userId;
        const senderName = sosData.user_name || 'Bir kullanici';
        const teamId = sosData.team_id;

        let tokens = [];

        if (teamId) {
            const usersSnap = await admin.firestore().collection('users').where('team_id', '==', teamId).get();
            usersSnap.forEach(doc => {
                if (doc.id !== userId) {
                    const data = doc.data();
                    if (data.fcmTokens && data.fcmTokens.length > 0) {
                        tokens = tokens.concat(data.fcmTokens);
                    }
                }
            });
        }
        
        if (tokens.length === 0) return null;

        const payload = {
            notification: {
                title: '🚨 ACIL DURUM (SOS) 🚨',
                body: ${senderName} acil durum sinyali gonderdi!,
            },
            data: {
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                type: 'sos',
                userId: userId
            }
        };

        return admin.messaging().sendEachForMulticast({
            tokens: tokens,
            notification: payload.notification,
            data: payload.data,
            android: {
                priority: 'high',
                notification: {
                    channelId: 'rota_plus_fcm_channel',
                    sound: 'default'
                }
            }
        });
    });
