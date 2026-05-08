$(document).ready(function () {
  // Initialize: set proper max-height for already-open sections
  document.querySelectorAll('.sidebar-section-header.open').forEach(function (header) {
    var targetId = header.getAttribute('data-toggle');
    var target = document.getElementById(targetId);
    if (target) {
      target.style.maxHeight = 'none';
      target.style.opacity = '1';
    }
  });

  // Click handler for toggling
  document.querySelectorAll('.sidebar-section-header').forEach(function (header) {
    header.addEventListener('click', function () {
      var targetId = header.getAttribute('data-toggle');
      var target = document.getElementById(targetId);

      if (!target) return;

      if (header.classList.contains('open')) {
        // Collapse
        target.style.maxHeight = target.scrollHeight + 'px';
        target.offsetHeight;
        target.style.maxHeight = '0';
        target.style.opacity = '0';
        header.classList.remove('open');

        target.addEventListener('transitionend', function handler() {
          if (!header.classList.contains('open')) {
            target.style.display = 'none';
          }
          target.removeEventListener('transitionend', handler);
        });
      } else {
        // Expand
        target.style.display = '';
        target.style.maxHeight = '0';
        target.style.opacity = '0';
        target.offsetHeight;
        target.style.maxHeight = target.scrollHeight + 'px';
        target.style.opacity = '1';
        header.classList.add('open');

        target.addEventListener('transitionend', function handler() {
          if (header.classList.contains('open')) {
            target.style.maxHeight = 'none';
          }
          target.removeEventListener('transitionend', handler);
        });
      }
    });
  });
});
