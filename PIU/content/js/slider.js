$(document).ready(function() {
	$("#slider").slider({
		range: "min",
		animate: true,
		value:1,
		min: 1,
		max: 99999,
		step: 500,
		slide: function(event, ui) {
		update(1,ui.value); //changed
		}
	});
  
	update();
});

//changed. now with parameter
function update(slider,val) {
	var $amount = 0;
	$amount = slider == 1 ? val : 0;
	$('#sliderVal').html('<p> Max price: '+$amount+'€</p>');
}