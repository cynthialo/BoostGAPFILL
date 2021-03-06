function MatricesSUX =generateSUXMatrix2(model,dictionary, KEGGFilename, KEGGBlackList, compartment, addModel,OldModel)
% generateSUXMatrix creates the matrices for matlab smiley -- > combines S, U
%  (KEGG), X (transport)
%
%    MatricesSUX =generateSUXMatrix(model,CompAbr, KEGGID,
%    KEGGFilename, compartment)
%
% model          model structure
% CompAbr        List of compounds abreviation (non-compartelized)
% KEGGID         List of KEGGIDs for compounds in CompAbr
% KEGGFilename   File name containing KEGG database
% KEGGBlackList
% compartment   [c] --> transport from cytoplasm [c] to extracellulat space
%               [e] (default), [p] creates transport from [c] to [p] and from [p] to [c],
%               if '' - no exchange reactions/transport will be added to the matrix.
% addModel      model structure, containing an additional matrix or model
%               that should be combined with SUX matrix.% Note that the naming of metabolites in this matrix has to be identical to
%               model naming. Also, the list should be unique.
%
% 11-10-07 IT
%

if nargin < 6
    addModel = '';
end

if nargin < 5
    compartment = '[c]';
end
if nargin < 4
    KEGGBlackList = {};
end
if nargin < 3
    KEGGFilename = '11-20-08-KEGG-reaction.lst';
end

% checks if model.mets has () or [] for compartment, or adds cytosol to
% compounds if no compartment is specified
model = CheckMetName(model);

%change the nomenclature of the universal metabolites
for i =1:length(OldModel.unModel.mets)
    temp=OldModel.unModel.mets{i};
    OldModel.unModel.mets{i}=strcat(temp(1:end-2),'[',temp(end),']');
end


% create KEGG Matrix - U
% KEGG = createUniversalReactionModel(KEGGFilename, KEGGBlackList);
% KEGG = transformKEGG2Model(KEGG,dictionary);
%
%
% %merge all 3 matrixes
% % 1. S with U
%
% model.RxnSubsystem = model.subSystems;
% KEGG.RxnSubsystem = KEGG.subSystems;
% nm=length(OldModel.mets);
nm=length(OldModel.unModel.mets);
% KEGG.rxns=setdiff(OldModel.unrnames',model.rxns);

[~,rem] = strtok(model.mets,'\[');
listCompartments = unique(rem);
cnt=1;

% for i=1:size(OldModel.unrnames,2)
for i=1:size(OldModel.unModel.rxns,1)
    
    tempMets=OldModel.unModel.mets(find(OldModel.unModel.S(:,i)));
    tempMetsID=cellfun(@(x) x(end-2:end),tempMets,'UniformOutput',false);
    
    testR=cell2mat(cellfun(@(x) prod(strcmp(tempMetsID,x)),listCompartments,'UniformOutput',false));
    if any(testR)&& ~any (strcmp(tempMetsID,'[e]'))
        KEGG.rxns(cnt,1)=OldModel.unModel.rxns(i);
        cnt=cnt+1;
    end
end

KEGG.S=sparse(OldModel.unModel.S(:,ismember(OldModel.unModel.rxns',KEGG.rxns)));
nr=length(KEGG.rxns);

KEGG.mets=OldModel.unModel.mets;

KEGG.b=zeros(nm,1);
KEGG.lb=-1000*ones(nr,1);
KEGG.ub=1000*ones(nr,1);
KEGG.subSystems=cell(nr,1);
KEGG.rxnNames=KEGG.rxns;
KEGG.rev=ones(nr,1);

[model_SU] = mergeTwoModels(model,KEGG,1,0);

% Adds an additional matrix if given as input
% Note that the naming of metabolites in this matrix has to be identical to
% model naming. Also, the list should be unique.
if isstruct(addModel)
    addModel = CheckMetName(addModel);
    [model_SU] = mergeTwoModels(model_SU,addModel,1,0);
end

if ~isempty(compartment)
    ExchangeRxnMatrix = createXMatrix(model_SU.mets,1,compartment);
    % 2. SU with X
    ExchangeRxnMatrix.RxnSubsystem = ExchangeRxnMatrix.subSystems;
    %model_SU.RxnSubsystem = model_SU.subSystems;
    [MatricesSUX] = mergeTwoModels(model_SU,ExchangeRxnMatrix,1,0);
    % creates a vector assigning the origin of the reactions to the parentfprintf(1,'Converting merged model into an irreversible model...');
else
    MatricesSUX=model_SU;
end

% MatricesSUX.rxnGeneMat(length(MatricesSUX.rxns),length(MatricesSUX.genes))=0;
% MatricesSUX.rxnGeneMat = sparse(MatricesSUX.rxnGeneMat);
MatricesSUX = convertToIrreversible(MatricesSUX);

% MatrixPart indicates in which area of MatricesSUX the model reactions,
% kegg reactions, and exchange/transport reactions are located (ie. 1 -
% model, 2 - kegg, 3 - X)
tmp=find(model.rev);
MatricesSUX.MatrixPart(1:length(model.rxns)+length(tmp),1)=1; % model reactions
MatricesSUX.MatrixPart(length(MatricesSUX.MatrixPart)+1:length(MatricesSUX.MatrixPart)+length(KEGG.rxns)+length(find(KEGG.rev)),1)=2;%KEGG DB reactions
MatricesSUX.MatrixPart(length(MatricesSUX.MatrixPart)+1:length(MatricesSUX.rxns),1)=3; %exchange and transport reactions

function model = CheckMetName(model)
% checks if model.mets has () or [] for compartment
if ~isempty(strfind(model.mets,'(c)')) ||~isempty(strfind(model.mets,'(e)'))
    for i = 1 :length(model.mets)
        model.mets{i} = regexprep(model.mets{i},'(','[');
        model.mets{i} = regexprep(model.mets{i},')',']');
    end
end
% fixes metabolites names if no compartment has been added to metabolites.
% It assumes that the metabolites without compartment are in the cytosol
for i = 1 :length(model.mets)
    if  isempty(regexp(model.mets{i},'\(\w\)')) && isempty(regexp(model.mets{i},'\[\w\]'))
        model.mets{i} = strcat(model.mets{i},'[c]');
    end
end
