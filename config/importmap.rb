# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "jquery", to: "https://ga.jspm.io/npm:jquery@3.6.3/dist/jquery.js"
pin "bootstrap", to: "https://ga.jspm.io/npm:bootstrap@4.6.1/dist/js/bootstrap.js"
pin "popper.js", to: "https://ga.jspm.io/npm:popper.js@1.16.1/dist/umd/popper.js"
pin "@ckeditor/ckeditor5-build-classic", to: "https://ga.jspm.io/npm:@ckeditor/ckeditor5-build-classic@35.3.1/build/ckeditor.js"
pin "@ckeditor/ckeditor5-build-decoupled-document", to: "https://ga.jspm.io/npm:@ckeditor/ckeditor5-build-decoupled-document@36.0.0/build/ckeditor.js"
pin "@rails/ujs", to: "https://ga.jspm.io/npm:@rails/ujs@7.0.4/lib/assets/compiled/rails-ujs.js"
pin "@fortawesome/fontawesome-free", to: "https://ga.jspm.io/npm:@fortawesome/fontawesome-free@6.2.1/js/fontawesome.js"
pin "@fortawesome/fontawesome-svg-core", to: "https://ga.jspm.io/npm:@fortawesome/fontawesome-svg-core@6.2.1/index.mjs"
pin "@fortawesome/free-brands-svg-icons", to: "https://ga.jspm.io/npm:@fortawesome/free-brands-svg-icons@6.2.1/index.mjs"
pin "@fortawesome/free-regular-svg-icons", to: "https://ga.jspm.io/npm:@fortawesome/free-regular-svg-icons@6.2.1/index.mjs"
pin "@fortawesome/free-solid-svg-icons", to: "https://ga.jspm.io/npm:@fortawesome/free-solid-svg-icons@6.2.1/index.mjs"

pin_all_from "app/javascript/controllers", under: "controllers"

# theme
pin "admin-lte", to: "https://ga.jspm.io/npm:admin-lte@3.2.0/dist/js/adminlte.min.js"

# DataTables, Buttons Plugin
pin "datatables.net", to: "https://ga.jspm.io/npm:datatables.net@1.13.1/js/jquery.dataTables.mjs"
pin "datatables.net-bs4", to: "https://ga.jspm.io/npm:datatables.net-bs4@1.13.1/js/dataTables.bootstrap4.mjs"
pin "datatables.net-responsive", to: "https://ga.jspm.io/npm:datatables.net-responsive@2.4.0/js/dataTables.responsive.mjs"
pin "datatables.net-responsive-bs4", to: "https://ga.jspm.io/npm:datatables.net-responsive-bs4@2.4.0/js/responsive.bootstrap4.mjs"
pin "datatables.net-buttons", to: "https://ga.jspm.io/npm:datatables.net-buttons@2.2.2/js/dataTables.buttons.js"
pin "datatables.net-buttons-bs4", to: "https://ga.jspm.io/npm:datatables.net-buttons-bs4@2.3.3/js/buttons.bootstrap4.mjs"
pin "datatables.net-buttons-html5", to: "https://cdn.datatables.net/buttons/2.3.2/js/buttons.html5.mjs"
pin "datatables.net-select-bs4", to: "https://ga.jspm.io/npm:datatables.net-select-bs4@1.5.0/js/select.bootstrap4.mjs"
pin "datatables.net-select", to: "https://ga.jspm.io/npm:datatables.net-select@1.5.0/js/dataTables.select.mjs"
pin "datatables.net-select-dt", to: "https://cdnjs.cloudflare.com/ajax/libs/datatables.net-select-dt/1.5.0/select.dataTables.min.js"
pin "@nathanvda/cocoon", to: "https://ga.jspm.io/npm:@nathanvda/cocoon@1.2.14/cocoon.js"

pin_all_from "app/javascript/lib", under: "lib"

#precompile javascript files

pin_all_from "app/javascript/custom_js", under: "custom_js"

# pin "api_utils", preload: true
# pin "header", preload: true
# pin "keyword_groups", preload: true
# pin "modal_handler", preload: true
# pin "settings", preload: true


pin "select2", to: "https://ga.jspm.io/npm:select2@4.1.0-rc.0/dist/js/select2.js"
pin "ckeditor", to: "ckeditor/ckeditor.js"
