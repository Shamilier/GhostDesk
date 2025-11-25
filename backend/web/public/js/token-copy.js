document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.copy-token').forEach((button) => {
    button.addEventListener('click', async () => {
      const token = button.dataset.token;
      if (!token) return;

      try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
          await navigator.clipboard.writeText(token);
        } else {
          const tempInput = document.createElement('input');
          tempInput.value = token;
          document.body.appendChild(tempInput);
          tempInput.select();
          document.execCommand('copy');
          document.body.removeChild(tempInput);
        }
        button.textContent = 'Скопировано!';
        button.classList.add('success');
        setTimeout(() => {
          button.textContent = 'Скопировать';
          button.classList.remove('success');
        }, 2000);
      } catch (error) {
        console.error('Не удалось скопировать токен', error);
        button.textContent = 'Ошибка';
        button.classList.add('error');
        setTimeout(() => {
          button.textContent = 'Скопировать';
          button.classList.remove('error');
        }, 2000);
      }
    });
  });
});
