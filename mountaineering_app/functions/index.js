const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendNotificationOnNewItem = functions.firestore
    .document("notifications/{userId}/items/{itemId}")
    .onCreate(async (snap, context) => {
        const notificationData = snap.data();
        const userId = context.params.userId;

        const type = notificationData.type || "";
        const fromUserName = notificationData.fromUserName || "Biri";
        const text = notificationData.text || "Yeni bir bildiriminiz var.";
        
        let title = "Acil Durum Bildirimi";
        if (type === "follow") title = "Yeni Takip";
        else if (type === "message") title = "Yeni Mesaj";
        else if (type === "like") title = "Yeni Beðeni";
        else if (type === "team_sos") title = "?? EKÝP SOS!";

        // Get user FCM tokens
        const userDoc = await admin.firestore().collection("users").doc(userId).get();
        if (!userDoc.exists) return null;

        const userData = userDoc.data();
        const fcmTokens = userData.fcmTokens || [];

        if (fcmTokens.length === 0) return null;

        const payload = {
            notification: {
                title: title,
                body: `${fromUserName} ${text}`,
            },
        };

        // Send FCM messages
        return admin.messaging().sendEachForMulticast({
            tokens: fcmTokens,
            notification: payload.notification,
            android: {
                priority: "high",
                notification: {
                    channelId: "rota_plus_fcm_channel",
                    sound: "default"
                }
            }
        });
    });
