importScripts(
  "https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js"
);

importScripts(
  "https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js"
);

firebase.initializeApp({
  apiKey: "AIzaSyC2V8jF0UhWAX6Q_ObCegjfZlX_kiJW4KM",
  authDomain: "hasani-payroll.firebaseapp.com",
  projectId: "hasani-payroll",
  storageBucket: "hasani-payroll.firebasestorage.app",
  messagingSenderId: "206112169695",
  appId: "1:206112169695:web:c3796d850c77f12678136a",
  measurementId: "G-XRMP5S4Y8J"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log(
    "[firebase-messaging-sw.js] Background message received:",
    payload
  );

  const notificationTitle =
    payload.notification?.title ||
    "Hasani Payroll";

  const notificationOptions = {
    body:
      payload.notification?.body ||
      "",
    icon: "/icons/Icon-192.png",
    data: payload.data || {}
  };

  self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});