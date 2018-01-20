
function mnist_example(varargin)
  % options (override by calling script with name-value pairs)
  opts.dataDir = [vl_rootnn() '/data/mnist'] ;  % MNIST data location
  opts.resultsDir = [vl_rootnn() '/data/mnist-example'] ;  % results location
  opts.numEpochs = 20 ;  % number of epochs
  opts.batchSize = 128 ;  % batch size
  opts.learningRate = 0.001 ;  % learning rate
  opts.gpu = 1 ;  % GPU index, empty for CPU mode
  opts.savePlot = false ;  % whether to save the plot as a PDF file
  
  opts = vl_argparse(opts, varargin) ;  % let user override options
  
  try run('../../setup_autonn.m') ; catch; end  % add AutoNN to the path
  mkdir(opts.resultsDir) ;
  

  % create network inputs
  images = Input('gpu', true) ;
  labels = Input() ;
  
  % create a LeNet (defined in 'autonn/matlab/+models/')
  output = models.LeNet('input', images);

  % create losses
  objective = vl_nnloss(output, labels, 'loss', 'softmaxlog') / opts.batchSize ;
  error = vl_nnloss(output, labels, 'loss', 'classerror') / opts.batchSize ;

  % assign layer names automatically, and compile network
  Layer.workspaceNames() ;
  net = Net(objective, error) ;


  % initialize solver
  solver = solvers.SGD('learningRate', opts.learningRate) ;
  
  % initialize dataset
  dataset = datasets.MNIST(opts.dataDir, 'batchSize', opts.batchSize) ;
  
  % compute average objective and error
  stats = Stats({'objective', 'error'}) ;
  
  % enable GPU mode
  net.useGpu(opts.gpu) ;

  for epoch = 1:opts.numEpochs
    % training phase
    for batch = dataset.train()
      % draw samples
      [images, labels] = dataset.get(batch) ;

      % evaluate network to compute gradients
      net.eval({'images', images, 'labels', labels}) ;
      
      % take one SGD step
      solver.step(net) ;

      % get current objective and error, and update their average
      stats.update(net) ;
      stats.print() ;
    end
    % push average objective and error (after one epoch) into the plot
    stats.push('train') ;

    % validation phase
    for batch = dataset.val()
      [images, labels] = dataset.get(batch) ;

      net.eval({'images', images, 'labels', labels}, 'test') ;

      stats.update(net) ;
      stats.print() ;
    end
    stats.push('val') ;

    % plot statistics
    stats.plot() ;
    if opts.savePlot && ~isempty(opts.expDir)
      print(1, [opts.expDir '/plot.pdf'], '-dpdf') ;
    end
  end

  % save results
  if ~isempty(opts.resultsDir)
    save([opts.resultsDir '/results.mat'], 'net', 'stats', 'solver') ;
  end
end
