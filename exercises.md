# Phiếu Phản Ánh — K4 Level 3B, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng placeholder ở mỗi câu bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Lê Thị Duyên  Mã học viên: 2A202602411

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống: Khi deploy ứng dụng lên môi trường Cloud (như Railway hoặc Render), nếu vô tình quên cấu hình biến môi trường `AGENT_API_KEY`:
- Nếu để giá trị mặc định là `"changeme"`, ứng dụng vẫn khởi động thành công và báo trạng thái Live. Bất kỳ ai cũng có thể gửi API key `"changeme"` để gọi API miễn phí và đốt sạch tiền token LLM của bạn mà bạn không hề hay biết cho tới khi nhận hóa đơn.
- Với cơ chế Fail fast (không có mặc định), ứng dụng sẽ dừng lại ngay lập tức (`ValidationError`) ngay trong quá trình container khởi động và báo lỗi trong log build/deploy. Việc "chết sớm" này buộc bạn phải cấu hình đúng secret bí mật trước khi ứng dụng tiếp nhận bất kỳ request công khai nào từ Internet.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
`{"event": "ask_completed", "level": "info", "timestamp": "2026-09-29T04:45:30.123456+00:00", "user_id": "sv-test", "tokens_in": 12, "tokens_out": 36, "cost_usd": 0.00015}`

Hai việc làm được với dòng log có cấu trúc trên:
1. **Lọc, tìm kiếm và tổng hợp tự động trên Cloud:** Các hệ thống quản lý log tập trung (như Datadog, Grafana Loki, AWS CloudWatch) có thể parse trực tiếp các trường JSON để lọc ra mọi request của một `user_id` cụ thể, hoặc tính tổng chi phí `sum(cost_usd)` theo từng giờ/ngày mà không phải dùng regex phức tạp.
2. **Thiết lập cảnh báo (Alerting) tự động theo ngưỡng:** Có thể thiết lập rule cảnh báo ngay khi trường `cost_usd > 0.01` hoặc khi `tokens_out` đột biến vượt ngưỡng cho phép, giúp phát hiện sớm tấn công hoặc lỗi vòng lặp logic.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1010 MB |
| Multi-stage | 175 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

Phần dung lượng chênh lệch (~835 MB) bao gồm:
- Toàn bộ các công cụ biên dịch (compilers như gcc, make, build-essential), thư viện header của hệ điều hành phục vụ việc cài đặt và compile wheel trong Python. Các công cụ này chỉ cần lúc build ở stage builder, hoàn toàn không cần thiết khi chạy runtime.
- Cache cài đặt của `pip` và các file tạm trong quá trình đóng gói.
- Bản phân phối Debian đầy đủ với rất nhiều package tiện ích và file tài liệu hệ thống thừa thãi, trong khi bản `python:3.11-slim` chỉ giữ lại nhân tối thiểu cần thiết để chạy Python.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Với Dockerfile hiện tại: Toàn bộ các layer cài đặt dependencies gồm `COPY requirements.txt .` và `RUN pip install --no-cache-dir -r requirements.txt` ở stage builder, cùng các layer tạo user và copy virtualenv ở stage runtime đều được **dùng lại hoàn toàn từ cache** (`CACHED`). Chỉ layer `COPY . .` và các layer sau nó trong stage runtime mới phải chạy lại, quá trình build chỉ mất 2-3 giây.
- Nếu đặt `COPY . .` lên trước `RUN pip install`: Mỗi khi bạn sửa bất kỳ file mã nguồn nào (dù chỉ 1 ký tự), Docker sẽ thấy checksum của thư mục thay đổi và vô hiệu hóa cache của lệnh `COPY . .`. Khi đó, toàn bộ các layer phía sau nó (bao gồm cả `RUN pip install`) bắt buộc phải tải và cài đặt lại toàn bộ thư viện từ đầu, làm tốn nhiều phút và tiêu tốn băng thông mạng một cách vô ích.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

- Chuỗi sự kiện leo thang đặc quyền:
  1. Ứng dụng Python có một lỗ hổng bảo mật (ví dụ như Remote Code Execution - RCE qua deserialization hoặc command injection).
  2. Kẻ tấn công khai thác lỗ hổng đó để thực thi lệnh shell bên trong container. Vì container mặc định chạy bằng user root (UID 0), kẻ tấn công chiếm toàn quyền root trong môi trường container.
  3. Kẻ tấn công tiếp tục khai thác một lỗ hổng nhân hệ điều hành (kernel privilege escalation) hoặc cấu hình sai (như mount socket `docker.sock` hoặc quyền SYS_ADMIN) để thực hiện container escape (thoát khỏi sandbox của container).
  4. Khi thoát ra được máy host, vì tiến trình container vốn chạy với UID 0, kẻ tấn công lập tức có luôn quyền root tối cao trên máy chủ vật lý của host.
- Lệnh `USER appuser` cắt đứt chuỗi tấn công ngay từ bước 2: Tiến trình chỉ chạy dưới quyền của một user không đặc quyền (UID 1000). Dù kẻ tấn công có chiếm được shell bên trong container, họ cũng không có quyền can thiệp vào các tệp tin hệ thống và không có quyền root để thực hiện các cuộc tấn công container escape ra máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

- Con số tối đa: Người dùng có thể gửi tới **20 request trong 2 giây liên tiếp**.
- Cách đạt được:
  - Ở giây thứ `10:00:59`, người dùng gửi dồn dập 10 request (vẫn hợp lệ với hạn mức 10 request của phút 10:00).
  - Ngay ở giây tiếp theo `10:01:00`, đồng hồ bước sang phút mới và bộ đếm tự động reset về 0. Người dùng gửi tiếp ngay lập tức 10 request nữa ở giây `10:01:01` (hợp lệ với hạn mức của phút 10:01).
  - Như vậy, trong khoảng thời gian chỉ vỏn vẹn 2 giây (từ 10:00:59 đến 10:01:01), hệ thống đã phải gánh tới 20 request (gấp đôi hạn mức cho phép), có thể gây sập server. Thuật toán Sliding Window ngăn chặn hoàn toàn điều này vì luôn tính tổng số request trong đúng 60 giây trôi qua tính từ thời điểm hiện tại.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Điểm khác nhau: Rate limit kiểm soát **tốc độ và số lượng request** trong một khoảng thời gian ngắn (bảo vệ tài nguyên tính toán của server khỏi bị nghẽn mạng hoặc quá tải). Cost guard kiểm soát **chi phí tài chính tích lũy** của người dùng theo chu kỳ ngân sách (bảo vệ ngân sách ví tiền khỏi bị cạn kiệt do tiêu thụ token LLM).
- Tình huống Rate limit cho qua nhưng Cost guard chặn: Người dùng mới chỉ gửi đúng 1 request trong phút (hoàn toàn hợp lệ với hạn mức 10 req/phút), nhưng tài khoản của người dùng này đã tiêu chạm mốc ngân sách $10.0 của tháng (hoặc câu hỏi có context quá lớn dẫn tới ước tính chi phí vượt ngân sách còn lại). Cost guard sẽ chặn lại và trả về mã lỗi 402 Payment Required.
- Tình huống Cost guard cho qua nhưng Rate limit chặn: Người dùng là tài khoản mới tinh, ngân sách còn nguyên $10.0 chưa tiêu đồng nào, nhưng lại dùng script tự động spam liên tiếp 15 request chỉ trong vòng 3 giây. Cost guard thấy tài khoản còn rất nhiều tiền, nhưng Rate limiter sẽ lập tức chặn từ request thứ 11 trả về mã lỗi 429 Too Many Requests để chống nghẽn hệ thống.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện xảy ra:
1. Khi Redis gặp sự cố hoặc ngắt kết nối mạng trong 30 giây, endpoint gộp này lập tức kiểm tra kết nối thất bại và trả về mã lỗi 503.
2. Bộ điều phối cụm (Orchestrator như Docker Swarm / Kubernetes / Cloud platform) thăm dò liveness probe định kỳ, thấy trả về lỗi 503 nên kết luận rằng cả 3 container agent đều đã bị lỗi hoặc treo tiến trình.
3. Orchestrator lập tức ra lệnh tiêu diệt và khởi động lại (restart) toàn bộ cả 3 container agent.
4. Sau khi khởi động lại, các container mới lại thăm dò endpoint và thấy Redis vẫn chưa sống lại (trong khoảng 30s sự cố) ➔ tiếp tục trả về 503 ➔ lại tiếp tục bị restart liên tục.
5. Cụm container rơi vào trạng thái khởi động lặp vô tận (**CrashLoopBackOff**). Toàn bộ hệ thống sập hoàn toàn và mọi request của người dùng (kể cả những request không cần tới Redis) đều bị rớt kết nối.

Tách riêng `/health` (chỉ kiểm tra process chạy) và `/ready` (kiểm tra dependency) giúp container không bị restart oan uổng; Load Balancer chỉ tạm thời ngưng đẩy traffic vào cho tới khi Redis phục hồi.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Nếu lịch sử được lưu trong dict Python trên RAM:
- Khi scale ra 3 container (`agent-1`, `agent-2`, `agent-3`), mỗi container là một tiến trình độc lập với vùng nhớ RAM hoàn toàn riêng biệt.
- Bộ cân bằng tải (Load Balancer / Nginx) chia đều các request theo cơ chế xoay vòng (round-robin). Khi cùng một user gửi liên tiếp các câu hỏi:
  - Request 1 đến `agent-1` ➔ `agent-1` lưu vào RAM của nó ➔ `history_length` là 0.
  - Request 2 rơi vào `agent-2` ➔ RAM của `agent-2` hoàn toàn trống rỗng ➔ `history_length` vẫn trả về là 0 (agent bị mất trí nhớ về câu hỏi trước).
  - Request 3 rơi vào `agent-3` ➔ RAM của `agent-3` cũng trống ➔ `history_length` vẫn là 0.
  - Request 4 quay lại `agent-1` ➔ `agent-1` tìm thấy câu hỏi ở request 1 ➔ `history_length` nhảy lên 2.
- Con số `history_length` sẽ nhảy lung tung (0, 0, 0, 2, 0...) và hội thoại bị đứt gãy hoàn toàn. Khi chuyển sang lưu tại Redis tập trung, cả 3 container cùng truy xuất một nguồn dữ liệu nên `history_length` sẽ tăng đều đặn và chính xác: 0 ➔ 2 ➔ 4 ➔ 6.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- **Thông báo lỗi gặp phải:** Khi kiểm tra service trên Railway, endpoint `/health` trả về 200 OK bình thường nhưng endpoint `/ready` lại trả về mã lỗi `503 Service Unavailable`.
- **Cách tìm ra nguyên nhân:** Tôi đối chiếu sự khác biệt giữa hai endpoint: `/health` chỉ kiểm tra tiến trình app (chạy độc lập), còn `/ready` gọi hàm `store.ping()` để kiểm tra kết nối tới Redis. Việc `/ready` trả về 503 chứng tỏ ứng dụng không thể kết nối tới cơ sở dữ liệu Redis. Khi vào tab Variables của service trên Railway, tôi phát hiện mình mới chỉ cấu hình `AGENT_API_KEY`, `LOG_LEVEL` mà chưa khai báo biến `REDIS_URL`.
- **Cách sửa chữa:** Tôi mở service Redis trên Railway, sao chép giá trị của biến `REDIS_URL` (dạng `redis://default:...`), sau đó quay lại tab Variables của service agent, bấm New Variable để tạo biến `REDIS_URL` rồi dán đường link vào và nhấn Deploy. Sau khi Railway cập nhật cấu hình, endpoint `/ready` lập tức trả về HTTP 200 `{"status":"ready","redis":true}`.
