wget https://raw.githubusercontent.com/zhuchcn/Metabase/master/vignettes/Introduction%20to%20Metabase.Rmd -O intro.Rmd

/usr/local/bin/R -e "rmarkdown::render('intro.Rmd', output_file = 'index.html')"