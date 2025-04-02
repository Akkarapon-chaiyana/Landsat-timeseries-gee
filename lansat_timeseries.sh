//////////////////////////////////////////////////////////////////////////////////////////////
//Title: The script below is to combome NDVI time series from Landsat 5 8 9
//Author: Tony (Akkarapon Chaiyana, D.Eng)
//Date: April 2, 2025
//Disclaimer: This script is provided for informational purposes only. Use at your own risk.          
//////////////////////////////////////////////////////////////////////////////////////////////

var counties = ee.FeatureCollection('projects/tony-1122/assets/TTU/selected_county');
var region = counties.filter(ee.Filter.inList('COUNTYNAME', ['Castro', 'Hale']));
Map.addLayer(region.draw('green'), {}, 'AOI');

// Import Landsat imagery.

var landsat5 = ee.ImageCollection("LANDSAT/LT05/C02/T1_L2");
var landsat8 = ee.ImageCollection('LANDSAT/LC08/C02/T1_L2');
var landsat9 = ee.ImageCollection("LANDSAT/LC09/C02/T1_L2");
// Functions to rename Landsat 7 and 8 images.
function renameL7(img) {
    return img.rename(['BLUE', 'GREEN', 'RED', 'NIR', 'SWIR1',
        'SWIR2', 'TEMP1', 'ATMOS_OPACITY', 'QA_CLOUD',
        'ATRAN', 'CDIST',
        'DRAD', 'EMIS', 'EMSD', 'QA', 'TRAD', 'URAD',
        'QA_PIXEL',
        'QA_RADSAT'
    ]);
}

function renameL8(img) {
    return img.rename(['AEROS', 'BLUE', 'GREEN', 'RED', 'NIR',
        'SWIR1',
        'SWIR2', 'TEMP1', 'QA_AEROSOL', 'ATRAN', 'CDIST',
        'DRAD', 'EMIS',
        'EMSD', 'QA', 'TRAD', 'URAD', 'QA_PIXEL', 'QA_RADSAT'
    ]);
}

function renameL9(img) {
    return img.rename(['AEROS', 'BLUE', 'GREEN', 'RED', 'NIR',
        'SWIR1',
        'SWIR2', 'TEMP1', 'QA_AEROSOL', 'ATRAN', 'CDIST',
        'DRAD', 'EMIS',
        'EMSD', 'QA', 'TRAD', 'URAD', 'QA_PIXEL', 'QA_RADSAT'
    ]);
}


// To mask out clouds, shadows, and other unwanted features
function addMask(img) {
    var clear = img.select('QA_PIXEL').bitwiseAnd(64).neq(0);
    clear = clear.updateMask(clear).rename(['pxqa_clear']);

    var water = img.select('QA_PIXEL').bitwiseAnd(128).neq(0);
    water = water.updateMask(water).rename(['pxqa_water']);

    var cloud_shadow = img.select('QA_PIXEL').bitwiseAnd(16).neq(0);
    cloud_shadow = cloud_shadow.updateMask(cloud_shadow).rename([
        'pxqa_cloudshadow'
    ]);

    var snow = img.select('QA_PIXEL').bitwiseAnd(32).neq(0);
    snow = snow.updateMask(snow).rename(['pxqa_snow']);

    var masks = ee.Image.cat([
        clear, water, cloud_shadow, snow
    ]);

    return img.addBands(masks);
}

function maskQAClear(img) {
    return img.updateMask(img.select('pxqa_clear'));
}

// Function to add NDVI as a band.
function addVIs(img){
  var ndvi = img.expression('(nir - red) / (nir + red)', {
      nir: img.select('NIR'),
      red: img.select('RED')
  }).select([0], ['NDVI']);
  
  return ee.Image.cat([img, ndvi]);
}

// Define study time period.
var start_date = '1995-01-01';
var end_date = '2024-12-31';

// Rename Landsat 7 8 and 9 and scope time period.
var landsat5coll = landsat5
    .filterBounds(region)
    .filterDate(start_date, end_date)
    .map(renameL7);

var landsat8coll = landsat8
    .filterDate(start_date, end_date)
    .filterBounds(region)
    .map(renameL8);

var landsat9coll = landsat9
    .filterDate(start_date, end_date)
    .filterBounds(region)
    .map(renameL9);

// Merge Landsat 7 and 8 collections.
var landsat = landsat5coll.merge(landsat8coll).merge(landsat9coll)
    .sort('system:time_start');

// Apply fucntion to imageCollection
landsat = landsat.map(addMask)
    .map(maskQAClear)
    .map(addVIs);

// print(landsat.limit(10));

// print(landsat.aggregate_histogram('LANDSAT_PRODUCT_ID').size());

// print(landsat.aggregate_histogram('LANDSAT_SCENE_ID').size());

// print(landsat.aggregate_histogram('system:index').size());


var landsatChart = ui.Chart.image.series({
  imageCollection: landsat.select('NDVI'),
  region        : point,
  reducer        : ee.Reducer.mean()})
    .setChartType('ScatterChart')
    .setOptions({
        title: 'Landsat NDVI time series',
        hAxis: {title: 'Time'},
        vAxis: {title: 'NDVI value'},
        lineWidth: 1,
        pointSize: 3,
});
print(landsatChart);

//////////////////////////////////////////////////////////////////////////////////////////////
//Title: The script below is to calculate NDVI time series by monthly averaged
//Author: Tony (Akkarapon Chaiyana, D.Eng)
//Date: July 13, 2025
//Disclaimer: This script is provided for informational purposes only. Use at your own risk.          
//////////////////////////////////////////////////////////////////////////////////////////////

var startYear = 1995;
var endYear   = 2024;
var years     = ee.List.sequence(startYear, endYear);
var months    = ee.List.sequence(1, 12, 1);

var landsat_ndvi = landsat.select('NDVI');

var NDVImonthly   = ee.ImageCollection.fromImages(
  years.map(function(y){
    return months.map(function(m){
      var z = landsat_ndvi.filter(ee.Filter.calendarRange(y,y,'year'))
                     .filter(ee.Filter.calendarRange(m, m, 'month')).mean();
      return z.set('year', y).set('month', m).set('system:time_start', ee.Date.fromYMD(y, m, 1));
    });
}).flatten());


var monthly_NDVI = ui.Chart.image.series({
  imageCollection: NDVImonthly,
  region        : region,
  scale         : 500,
  reducer        : ee.Reducer.mean()})
    .setChartType('ScatterChart')
    .setOptions({
        title: 'Landsat monthly NDVI time series by specific region',
        hAxis: {title: 'Time'},
        vAxis: {title: 'NDVI value'},
        lineWidth: 1,
        pointSize: 3,
});
print(monthly_NDVI);



var monthly_NDVI = ui.Chart.image.seriesByRegion({
  imageCollection: NDVImonthly,
  regions        : region,
  scale         : 50,
  reducer        : ee.Reducer.mean()})
    .setChartType('ScatterChart')
    .setOptions({
        title: 'Landsat monthly NDVI time series by entire region',
        hAxis: {title: 'Time'},
        vAxis: {title: 'NDVI value'},
        lineWidth: 1,
        pointSize: 3,
});
print(monthly_NDVI);
