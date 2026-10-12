// Firefox VA-API 硬件解码（2026-10-12）
// 依赖 mesa-va-drivers-freeworld（RPM Fusion）提供 H.264/H.265 VLD，
// 仅装 Fedora 官方 mesa-va-drivers 时 vainfo 只有 VP9/AV1/JPEG，H.264 走软解，
// 表现为拖进度条音频超前、画面跟不上。
//
// 撤销顺序（三步缺一不可，否则重启后设置会被本文件再次写入）：
//   1. 删除本文件，或恢复此前的 user.js.bak.<timestamp> 备份
//   2. Firefox about:config 中把下面两项重置（右键 → 重置）
//   3. 重启 Firefox
//   media.ffmpeg.vaapi.enabled
//   media.hardware-video-decoding.enabled
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.enabled", true);
