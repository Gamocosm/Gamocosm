// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

import 'jquery';
import 'bootstrap';

import 'jquery-ujs';

import 'servers';
import 'volumes';

(function($) {
	$('[data-toggle="tooltip"]').tooltip()
})(jQuery);
