# Referensi overlay

- [gili](https://github.com/maulanarizky16/gili) menggunakan jendela WinForms popup dengan layered, tool-window, topmost dan no-activate; posisi dihitung dari batas monitor dan DPI. NotchUI tetap menggunakan HWND WinUI sendiri dengan topmost, ukuran berbasis DPI, region, dan `SWP_NOACTIVATE` saat reposisi. Implementasi tidak disalin.
- [Poni](https://github.com/liimalim/Poni) pada snapshot yang tersedia berisi dokumentasi, aset dan terjemahan, tanpa source implementasi jendela. Karena itu mekanisme overlay Poni tidak dapat diverifikasi dari repository tersebut.

Opasitas mengatur brush latar notch, bukan teks atau kontrol. Transparansi, interaksi, performa animasi, dan tampilan harus diuji pada Windows; build CI saja tidak membuktikannya.
