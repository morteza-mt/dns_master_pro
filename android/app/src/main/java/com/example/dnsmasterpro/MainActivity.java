package com.mory65.dnsmasterpro;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import android.content.Intent;
import android.net.VpnService;
import android.net.ConnectivityManager;
import android.net.NetworkCapabilities;
import android.os.Build;
import androidx.annotation.NonNull;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.mory65.dnsmasterpro/vpn";
    private String lastDnsAddr = "8.8.8.8";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("applyDNS")) {
                        String dnsAddr = call.argument("dns");
                        if (dnsAddr != null) lastDnsAddr = dnsAddr;

                        Intent intent = VpnService.prepare(this);
                        if (intent != null) {
                            startActivityForResult(intent, 0);
                        } else {
                            startVpnService(lastDnsAddr);
                        }
                        result.success("سرویس DNS فعال شد");
                    } else if (call.method.equals("stopDNS")) {
                        stopVpnService();
                        result.success("سرویس متوقف شد");
                    } else if (call.method.equals("isVpnActive")) {
                        result.success(checkVpnStatus());
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private void startVpnService(String dns) {
        Intent intent = new Intent(this, DNSVpnService.class);
        intent.putExtra("dns", dns);
        startService(intent);
    }

    private void stopVpnService() {
        Intent intent = new Intent(this, DNSVpnService.class);
        intent.setAction("STOP");
        startService(intent);
    }


    private boolean checkVpnStatus() {
        return DNSVpnService.isRunning;
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (resultCode == RESULT_OK) {
            startVpnService(lastDnsAddr);
        }
    }
}