document.addEventListener('DOMContentLoaded', () => {
    const waitlistForm = document.getElementById('waitlist-form');
    const waitlistSuccess = document.getElementById('waitlist-success');
    const emailInput = waitlistForm.querySelector('input[type="email"]');
    const submitBtn = waitlistForm.querySelector('button');

    // Get source from URL if present (e.g., website.com/?s=twitter)
    const urlParams = new URLSearchParams(window.location.search);
    const source = urlParams.get('s') || 'website';

    waitlistForm.addEventListener('submit', async (e) => {
        e.preventDefault();

        const email = emailInput.value;
        if (!email) return;

        // Visual feedback
        submitBtn.disabled = true;
        submitBtn.textContent = 'Joining...';

        // Detect environment
        const apiBaseUrl = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
            ? 'http://localhost:4000'
            : 'https://chillnote-backend.vercel.app'; // Replace with your ACTUAL production backend URL

        try {
            const response = await fetch(`${apiBaseUrl}/waitlist`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ email, source }),
            });

            const data = await response.json();

            if (data.success) {
                waitlistForm.style.display = 'none';
                waitlistSuccess.style.display = 'block';

                // Add "Share on Twitter" functionality
                const twitterShareBtn = document.createElement('a');
                twitterShareBtn.href = `https://twitter.com/intent/tweet?text=${encodeURIComponent("I just joined the waitlist for ChillNote! 📝✨ Capture your thoughts at the speed of sound. Join me here: https://chillnoteai.com")}`;
                twitterShareBtn.className = 'btn btn-secondary';
                twitterShareBtn.style.marginTop = '1.5rem';
                twitterShareBtn.style.background = '#1DA1F2';
                twitterShareBtn.style.color = 'white';
                twitterShareBtn.style.border = 'none';
                twitterShareBtn.innerHTML = '<svg style="width: 16px; height: 16px; vertical-align: middle; margin-right: 8px; fill: white;" viewBox="0 0 24 24"><path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.84 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/></svg> Spread the word on Twitter';
                twitterShareBtn.target = '_blank';

                waitlistSuccess.appendChild(twitterShareBtn);
            } else {
                alert(data.error || 'Something went wrong. Please try again.');
                submitBtn.disabled = false;
                submitBtn.textContent = 'Get Early Access';
            }
        } catch (error) {
            console.error('Error:', error);
            alert('Could not connect to the server. Please check your internet or try again later.');
            submitBtn.disabled = false;
            submitBtn.textContent = 'Get Early Access';
        }
    });
});
