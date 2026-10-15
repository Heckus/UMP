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
\RequirePackage{hyperref}
\hypersetup{
    colorlinks=true,
    linkcolor=black,
    citecolor=black,
    filecolor=black,
    urlcolor=black
}
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
\setulmarginsandblock{30mm}{30mm}{*}
\setheadfoot{20mm}{\baselineskip}
\setheaderspaces{*}{\baselineskip}{*}
\OnehalfSpacing
\raggedbottom % Prevents LaTeX from stretching vertical gaps between paragraphs to fill pages
\def\keywordname{{\bf Keywords:}}



%Make sure that TeX sorts out the geometry correctly.
\checkandfixthelayout

% ********* Chapter and section style **********
\makechapterstyle{mychapterstyle}{%
    \setlength{\beforechapskip}{10pt}%   % Default is 50pt
    \setlength{\midchapskip}{10pt}%      % Space between 'Chapter X' and Title
    \setlength{\afterchapskip}{20pt}%    % Default is 40pt
    \renewcommand{\chapnamefont}{\Large\rmfamily\bfseries}%
    \renewcommand{\chapnumfont}{\Large\rmfamily\bfseries}%
    \renewcommand{\chaptitlefont}{\LARGE\rmfamily\bfseries}%
    \renewcommand{\printchaptertitle}[1]{%
        \chaptitlefont\hrule height 0.5pt \vspace{0.6em}%
        {##1}\vspace{0.6em}\hrule height 0.5pt%
    }%
    \renewcommand{\printchapternum}{\chapnumfont\thechapter}%
}
\chapterstyle{mychapterstyle}

\setsecheadstyle{\Large\rmfamily\bfseries}
\setsubsecheadstyle{\large\rmfamily\bfseries}
\setsubsubsecheadstyle{\normalfont\rmfamily\bfseries}
\setparaheadstyle{\normalfont\rmfamily}

\makeevenhead{headings}{\thepage}{}{\small\slshape\leftmark}
\makeoddhead{headings}{\small\slshape\rightmark}{}{\thepage}

% ---- Use native memoir pagestyles instead of conflicting fancyhdr ----
\makepagestyle{myfancy}
\makeevenfoot{myfancy}{}{}{Page \thepage}
\makeoddfoot{myfancy}{}{}{Page \thepage}
\makeevenhead{myfancy}{}{\small\slshape\leftmark}{}
\makeoddhead{myfancy}{}{\small\slshape\rightmark}{}

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
\OnehalfSpacing
\raggedbottom % Prevents LaTeX from stretching vertical gaps between paragraphs to fill pages
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

% Tighten spacing around figures and tables
\setlength{\textfloatsep}{12pt plus 2pt minus 2pt}
\setlength{\floatsep}{10pt plus 2pt minus 2pt}
\setlength{\intextsep}{12pt plus 2pt minus 2pt}
\setlength{\abovecaptionskip}{6pt}
\setlength{\belowcaptionskip}{4pt}

% Allow more space on a page to be occupied by floats before pushing to a new page
\renewcommand{\topfraction}{0.85}
\renewcommand{\bottomfraction}{0.85}
\renewcommand{\textfraction}{0.10}
\renewcommand{\floatpagefraction}{0.80}



