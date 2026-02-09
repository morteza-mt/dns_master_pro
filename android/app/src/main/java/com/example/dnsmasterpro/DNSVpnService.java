package com.mory65.dnsmasterpro;

import android.content.Intent;
import android.net.VpnService;
import android.os.ParcelFileDescriptor;
import android.util.Log;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.os.Build;
import androidx.core.app.NotificationCompat;

public class DNSVpnService extends VpnService {
    private ParcelFileDescriptor vpnInterface = null;

    public static boolean isRunning = false;

    private static final String CHANNEL_ID = "dns_master_channel";

    @Override
    public void onCreate() {
        super.onCreate();
        isRunning = true;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // ۱. بررسی دستور توقف
        if (intent != null && "STOP".equals(intent.getAction())) {
            closeVpn();
            return START_NOT_STICKY;
        }

        String dns = (intent != null) ? intent.getStringExtra("dns") : "8.8.8.8";

        showNotification(dns);

        setupVpn(dns);

        return START_STICKY;
    }

    private void setupVpn(String dns) {
        try {
            if (vpnInterface != null) {
                vpnInterface.close();
            }

            VpnService.Builder builder = new VpnService.Builder();

            builder.addDisallowedApplication("com.mory65.dnsmasterpro");

            builder.setSession("DNS Master Pro")
                    .setMtu(1500)
                    .addAddress("10.0.0.2", 32)
                    .addDnsServer(dns);


            vpnInterface = builder.establish();
            isRunning = true;
            Log.d("DNSVpnService", "VPN Interface established with DNS: " + dns);

        } catch (Exception e) {
            Log.e("DNSVpnService", "Error setting up VPN", e);
            isRunning = false;
            stopSelf();
        }
    }
    private void showNotification(String dns) {
        NotificationManager manager = (NotificationManager) getSystemService(NotificationManager.class);
        String channelId = "dns_master_channel";

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    channelId, "DNS Service", NotificationManager.IMPORTANCE_LOW);
            if (manager != null) manager.createNotificationChannel(channel);
        }

        Intent notificationIntent = new Intent(this, MainActivity.class);
        // استفاده از FLAG_UPDATE_CURRENT برای اطمینان از کارکرد اینتنت
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0,
                notificationIntent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);

        Intent stopIntent = new Intent(this, DNSVpnService.class);
        stopIntent.setAction("STOP");
        PendingIntent stopPendingIntent = PendingIntent.getService(this, 1,
                stopIntent, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);

        NotificationCompat.Builder builder = new NotificationCompat.Builder(this, channelId)
                .setContentTitle("DNS Master Pro")
                .setContentText("DNS Active: " + dns)
                // استفاده از آیکون سیستمی برای تست (حتما این رو چک کن)
                .setSmallIcon(R.drawable.ic_notification)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setColor(0xFF2196F3)
                .setOngoing(true)
                .setContentIntent(pendingIntent)
                .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Disconnect", stopPendingIntent);

        // شروع سرویس در پیش‌زمینه
        startForeground(1, builder.build());
    }

    private void closeVpn() {
        isRunning = false;
        try {
            if (vpnInterface != null) {
                vpnInterface.close();
                vpnInterface = null;
            }
        } catch (Exception e) {
            Log.e("DNSVpnService", "Close Error", e);
        }

        // --- ارسال پیغام به فلاتر برای قطع شدن ---
        Intent broadcastIntent = new Intent("com.mory65.dnsmasterpro.VPN_STATE_CHANGED");
        broadcastIntent.putExtra("status", "disconnected");
        sendBroadcast(broadcastIntent);
        // ---------------------------------------

        stopForeground(true);
        stopSelf();
    }

    @Override
    public void onDestroy() {
        isRunning = false;
        closeVpn();
        super.onDestroy();
    }

    @Override
    public void onRevoke() {
        // اگر کاربر از تنظیمات گوشی VPN را قطع کرد
        isRunning = false;
        closeVpn();
        stopSelf();
        super.onRevoke();
    }


}