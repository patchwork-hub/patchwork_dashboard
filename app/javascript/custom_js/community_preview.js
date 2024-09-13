document.addEventListener('DOMContentLoaded', function() {
  const buttons = document.querySelectorAll('.btn-group-toggle .btn');
  
  buttons.forEach(button => {
    button.addEventListener('click', function() {
      buttons.forEach(btn => btn.classList.remove('selected'));
      
      this.classList.add('selected');
      
      const radio = this.querySelector('input[type="radio"]');
      if (radio) {
        radio.checked = true;
      }
    });
  });
});
