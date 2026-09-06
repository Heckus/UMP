%*************************************
% Thesis Formatting Style Class for QUT Honours theses
%*************************************
% qutthesis.cls

% This file defines the formatting style for your thesis in accordance with the Thesis Format Requirements (See QUT thesis requirements
% https://cms.qut.edu.au/__data/assets/pdf_file/0004/7249/requirements_for_presenting_theses.pdf

%*************************************
% Class structure: identification part
%*************************************

\ProvidesClass{qutthesis}[]
\NeedsTeXFormat{LaTeX2e}[2016/05/16]

%Load the memoir class.
\LoadClass[12pt, a4paper, oneside, openany]{memoir}

%*************************************
% Load packages
%*************************************
\RequirePackage{mathptmx} 							
%Set the font to Times New Roman. This package also alters the math-mode font to TNR.
\RequirePackage{graphicx} %Use pdfLaTeX.
\RequirePackage{booktabs, longtable} 		
%allow tables to split over pages. Very useful in theses!
\RequirePackage{url} %Typeset urls properly.
% \RequirePackagecolorlinks{hyperref}		
\usepackage{hyperref}
\hypersetup{colorlinks=true, citecolor=black, linkcolor=black}
%Hyperlink your pdf output.
\RequirePackage{geometry} %set the margins.
\RequirePackage{memhfixc} % Set the correct layout
\RequirePackage{amsmath,amssymb,amsthm} %Useful maths packages.
\RequirePackage{setspace} %Set line space.
\RequirePackage{qut-title} %Get the title page right.
\RequirePackage{comment}								
%Use this to enable easy inclusion/exclusion of instructions (at request of grad school).

%*************************************
% Turn off instructional comments
%*************************************
%This section of code allows the template user to turn off the instructional comments with a single option.
%Adapted from https://tex.stackexchange.com/questions/135248/if-not-declareoption
	\newif\ifmycomments@comments
	\DeclareOption{instructions}{\mycomments@commentstrue}
	\DeclareOption{final}{\mycomments@commentsfalse}
	\ExecuteOptions{draft} % default is to have no comments.
	\excludecomment{instructional}
	\ProcessOptions\relax
	\ifmycomments@comments
		\includecomment{instructional} %include comments if true
	\fi

%*************************************
% Set page and heading styles
%*************************************
% ********* Set page layout **********
\setlrmarginsandblock{30mm}{30mm}{*}
\setulmarginsandblock{25mm}{25mm}{*}
\setheadfoot{20mm}{\baselineskip}
\setheaderspaces{*}{\baselineskip}{*}
\def\baselinestretch{1}
\def\keywordname{{\bf Keywords:}}



%Make sure that TeX sorts out the geometry correctly.
\checkandfixthelayout

% ********* Chapter and section style **********
% \makechapterstyle{mychapterstyle}{%
%     \renewcommand{\chapnamefont}{\LARGE\rmfamily\bfseries}%
%     \renewcommand{\chapnumfont}{\LARGE\rmfamily\bfseries}%
%     \renewcommand{\chaptitlefont}{\LARGE\rmfamily\bfseries}%
%     \renewcommand{\printchaptertitle}[1]{%
%         \chaptitlefont\hrule height 0.5pt \vspace{1em}%
%         {##1}\vspace{1em}\hrule height 0.5pt%
%         }%
%     \renewcommand{\printchapternum}{%
%         \chapnumfont\thechapter%
%         }%
% }

\makechapterstyle{mychapterstyle}{%
    % --- Add these length adjustments to pull the title up ---
    \setlength{\beforechapskip}{30pt} % Set to positive to add space before the chapter
    \setlength{\midchapskip}{0pt}      % Removes the hidden gap where the chapter number was
    
    \renewcommand{\chapnamefont}{\LARGE\rmfamily\bfseries}%
    \renewcommand{\chapnumfont}{\LARGE\rmfamily\bfseries}%
    \renewcommand{\chaptitlefont}{\Huge\rmfamily\bfseries}%
    
    \renewcommand{\printchaptername}{} 
    \renewcommand{\printchapternum}{} 
    
    \renewcommand{\printchaptertitle}[1]{%
        \chaptitlefont\hrule height 0.5pt \vspace{1em}%
        {##1}\vspace{1em}\hrule height 0.5pt%
        }%
}

% Prevent chapters from automatically starting on a new page
\renewcommand{\clearforchapter}{}

\chapterstyle{mychapterstyle}

\setsecheadstyle{\Large\rmfamily\bfseries}
\setsubsecheadstyle{\large\rmfamily\bfseries}
\setsubsubsecheadstyle{\normalfont\rmfamily\bfseries}
\setparaheadstyle{\normalfont\rmfamily}

\makeevenhead{headings}{\thepage}{}{\small\slshape\leftmark}
\makeoddhead{headings}{\small\slshape\rightmark}{}{\thepage}

% ---- Use native memoir pagestyles instead of fancyhdr ----
\makepagestyle{myfancy}
\makeevenfoot{myfancy}{}{}{Page \thepage}
\makeoddfoot{myfancy}{}{}{Page \thepage}
\makeevenhead{myfancy}{}{}{}
\makeoddhead{myfancy}{}{}{}

\pagestyle{myfancy}
\aliaspagestyle{chapter}{myfancy}
\aliaspagestyle{plain}{myfancy}
\aliaspagestyle{headings}{myfancy}
% ********* Table of contents style **********
\settocdepth{subsection}

\setsecnumdepth{subsection}
\maxsecnumdepth{subsection}
\settocdepth{subsection}
\maxtocdepth{subsection}

\renewcommand{\listfigurename}{List of Figures}
\renewcommand{\listtablename}{List of Tables}

% ********* General page styles **********

%Get the correct line spacing. Note that \onehalfspacing DOES NOT work because of the way which LaTeX measures linespacing (which is different to Word).
\linespread{1.5}
%Make sure footnotes don't split over a page.
\interfootnotelinepenalty=10000

%*************************************
% Fix white space to improve readability
%*************************************
%Redefine the sqrt command so that it puts a space after the surd.
%This makes AMSMATH much easier to read.
%COMMENT THIS OUT OR DELETE IF YOU DON'T WISH TO USE IT.
\let\SQRT\sqrt
\renewcommand{\sqrt}[1]{\ensuremath{\SQRT{#1} \;}}


