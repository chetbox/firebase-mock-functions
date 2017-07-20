var gulp = require('gulp');
var gutil = require('gulp-util');
var coffeescript = require('gulp-coffeescript');

gulp.task('build', function() {
  gulp.src('./src/*.coffee')
    .pipe(coffeescript({bare: true}).on('error', gutil.log))
    .pipe(gulp.dest('./lib/'));
});
