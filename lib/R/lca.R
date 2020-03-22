# =========================================================
# Copyright 2019-2020,  Nuno A. Fonseca (nuno dot fonseca at gmail dot com)
#
#
# This is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# if not, see <http://www.gnu.org/licenses/>.
#
#
# =========================================================


##
## unknown??
##
## remove.trailing.nas=TRUE - removes :NA  from the end of the path.
##                     e.g. level1:level2:NA:NA becomes level1:level2
## normalize.entries=TRUE - remove trailing numbers, .sp and words after the first space for the last entry in the path
lca <- function(paths, threshold=1.0, sep=":",                
                remove.dups=FALSE,
                normalize.entries=FALSE,
                remove.trailing.nas=FALSE) {
    
    if (is.null(paths)) return(NA)
    # remove dups...  or not 
    if (remove.dups) paths<-paths[!duplicated(paths)]
    ## Normalize netries
    if ( normalize.entries ) {
        paths <- sapply(paths,FUN=sub,pattern=" [^:]+$",replacement="",ignore.case=TRUE)
        paths <- sapply(paths,FUN=sub,pattern="([^0-9])[0-9]+$",replacement="\\1",ignore.case=TRUE)
        
    }

    ## remove trailing NAs
    if ( remove.trailing.nas ) {
        paths <- sapply(paths,FUN=sub,pattern="(:NA)+$",replacement="",ignore.case=TRUE)   
    }
    ## workaround to handle paths with toplevel entries only
    paths<-paste(paths,":NA-",sep="")
    v<-sapply(paths,function(l) strsplit(l,sep)[[1]])
    ##
    if ( typeof(v) == "list" ) {
        ## ensure that length of all elements is the same
        lens<-sapply(v,length)
        target<-max(lens,na.rm=TRUE)
        unilength<-function(l,tlen) {
            nnewels<-tlen-length(l)
            if (nnewels==0) return(l)
            return(append(l,rep(x="NA",nnewels)))
        }
        v<-lapply(v,unilength,tlen=target)
    } 
    
    v<-data.frame(v,check.names=FALSE,stringsAsFactors=FALSE)    
    nt<-apply(v,1,table,useNA="no")
    if (typeof(nt) == "integer") {
        ## single entry        
        return(sub(":NA-$","",x=paths[1]))
    }
    vals<-lapply(nt,function(x) x/sum(x,na.rm=TRUE))#,simplify=FALSE)
        
    w<-NA
    for ( e in 1:length(vals)) {
          w<-vals[[e]]
          if (max(w)<threshold) {
            e<-e-1
            break;
        }
    }
    if (e==0) return(NA)
    w<-vals[[e]]
    # get the full paths
    l<-names(which(w>=threshold))
    cols<-as.character(v[e,])%in%l
    v2<-v[1:e,cols,drop=FALSE]

    r<-unique(apply(v2,c(2),paste,sep=sep,collapse=sep))
    return(sub(":NA-$","",x=r))
}

test_lca <- function () {
  stopifnot(is.na(lca(NULL)))

  passed<-0
  failed<-0
  tests<-list()
  tests[["t1"]]<-list(input=c("1:2","1:3"),output=c("1"))
  #tests[["t2"]]<-list(input=c("a:b","a:b"),output=c("1:2"))
  tests[["t2"]]<-list(input=c("1:2","1:2"),output=c("1:2"))
  tests[["t3"]]<-list(input=c("a:b","a:c"),output=c("a"))
  tests[["t4"]]<-list(input=c("a:b:c:d","a:c:d:e"),output=c("a"))
  tests[["t5"]]<-list(input=c("a:b:c:d","a:b:c:d:e"),output=c("a:b:c:d"))
  tests[["t6"]]<-list(input=c("a:b:c:d","a:b:c:d:e","a:b:c:d:e"),output=c("a:b:c:d"))
  tests[["t7"]]<-list(input=c("a:b:c:d","a:b:c:d:e","a:b:c:d:e"),threshold=0.6,output=c("a:b:c:d:e"))
  tests[["t8"]]<-list(input=c("1"),output=c("1"))
  tests[["t9"]]<-list(input=c("1:2","1:2","1:2"),output=c("1:2"))
  tests[["t10"]]<-list(input=c("1:2","1:2","1:2","1:3"),output=c("1"))
  tests[["t11"]]<-list(input=c("1:2","1:2","1:2","1:3:4"),output=c("1"))
  tests[["t12"]]<-list(input=c("1:2","1:2","1:2","1:2:4"),output=c("1:2"))
  tests[["t13"]]<-list(input=c("1","2","1","1"),output=NA)
  tests[["t14"]]<-list(input=c("1","2","2","1"),output=NA)
  tests[["t15"]]<-list(input=c("1","2","2","1"),output=NA,remove.trailing.nas=TRUE)
  tests[["t16"]]<-list(input=c("1:2:NA:NA:NA:NA","1:2:NA","1:2","1:2:4:NA"),output=c("1:2"),remove.trailing.nas=TRUE)
  tests[["t17"]]<-list(input=c("1:2:NA:NA:NA:NA","1:2:NA","1:2:s1","1:2:4:NA","1:2:3 sp","1:2:3 12"),output=c("1:2"),remove.trailing.nas=TRUE,normalize.entries=TRUE)


  
  for ( t in names(tests)) {
    print(t)
    thr<-tests[[t]]$threshold
    if (is.null(thr)) thr<-1.0
    v<-lca(tests[[t]]$input,threshold = thr)
    if ( (is.na(tests[[t]]$output) && is.na(v)) ||
         ( !is.na(v) && v==tests[[t]]$output ) ) {
        passed <- passed+1
        print("OK")
    } else {
        failed <- failed+1
        print(v)
        print("FAILED")
    }
  }
  if (failed>0) {
      print("SOME TESTS FAILED")
      return(FALSE)
  } else {
      return(TRUE)
  }
}

##test_lca()
